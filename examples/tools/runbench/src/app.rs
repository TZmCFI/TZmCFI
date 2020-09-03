use atomic_refcell::AtomicRefCell;
use regex::bytes::Regex;
use serde::Serialize;
use std::{error::Error, future::Future, path::PathBuf};
use thiserror::Error;

use super::{build_target, subprocess, target, BuildOpt, SesType};

pub mod bench_coremark;
pub mod bench_latency;
pub mod bench_rtos;
pub mod profile_rtos;
pub mod profile_ses;

/// Describes the traits of a Non-Secure benchmark application.
pub trait AppTraits {
    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of shadow exception stacks.
    ///
    /// When this flag is `false`, `ses` will be always enabled.
    fn should_use_shadow_exception_stacks(&self) -> bool;

    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of shadow stacks.
    fn should_use_shadow_stacks(&self) -> bool;

    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of the context management API.
    ///
    /// When this flag is `false`, `ctx` will be always enabled.
    fn should_use_context_management(&self) -> bool;

    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of accelerated privilege escalation.
    fn should_use_accel_raise_pri(&self) -> bool;

    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of the LLVM icall sanitizer.
    fn should_use_icall_sanitizer(&self) -> bool;

    /// The name of the benchmark application used for a `zig build` parameter
    /// and the produced binary.
    fn name(&self) -> String;

    /// Get the string indicating the end of output.
    ///
    /// The default value is `b"%output-end"`.
    fn output_terminator(&self) -> &[u8] {
        b"%output-end"
    }

    /// Post-process the output.
    ///
    /// By default, this method extracts the contents between `b"%output-start"`
    /// and `b"%output-end"`.
    fn process_output(&self, output: &[u8]) -> Result<Option<Vec<u8>>, Box<dyn Error>> {
        if let Some(m) = OUTPUT_RE.captures(output) {
            Ok(Some(m[1].to_owned()))
        } else {
            Err(
                "Could not locate a byte sequence enclosed by `%output-start` and `%output-end`."
                    .into(),
            )
        }
    }
}

lazy_static::lazy_static! {
    static ref OUTPUT_RE:Regex = Regex::new(r"(?s).*%output-start\s*(.*?)\s*%output-end").unwrap();
}

pub(crate) async fn run(opt: &super::Opt, traits: impl AppTraits) -> Result<(), Box<dyn Error>> {
    let mut target = build_target(opt).await?;

    let build_opts = BuildOpt::all_valid_values(opt).filter(|bo| {
        if !traits.should_use_shadow_exception_stacks() && bo.ses != Some(SesType::Safe) {
            return false;
        }
        if !traits.should_use_shadow_stacks() && bo.ss {
            return false;
        }
        if !traits.should_use_context_management() && !bo.ctx {
            return false;
        }
        if !traits.should_use_accel_raise_pri() && bo.accel_raise_pri {
            return false;
        }
        if !traits.should_use_icall_sanitizer() && bo.icall {
            return false;
        }
        true
    });

    log::info!("The following build options will be tested:");
    for bo in build_opts.clone() {
        log::info!(" - {}", bo);
    }
    let build_opts_len = build_opts.clone().count();

    let output_dir = opt.output_dir();
    log::info!("The output will be saved to: {:?}", output_dir);
    tokio::fs::create_dir_all(&output_dir)
        .await
        .map_err(|e| RunBenchmarkError::CreateOutputDirError(e.into()))?;

    let mut meta = Metadata {
        benchmark: opt.benchmark,
        target: opt.target,
        exe_names: MetaExeNames {
            secure: "secure".to_owned() + ".elf",
            non_secure: traits.name() + ".elf",
        },
        matrix: Vec::new(),
    };

    for (i, bo) in build_opts.enumerate() {
        log::info!("* Build option: {} ({} of {})", bo, i + 1, build_opts_len);

        // The ELF images
        let secure_elf = opt.zig_cache_dir.join("secure");
        let nonsecure_elf = opt.zig_cache_dir.join(traits.name());

        // Delete the images just in case
        log::trace!("Deleting {:?} and {:?}", secure_elf, nonsecure_elf);
        let (r1, r2) = tokio::join!(
            tokio::fs::remove_file(&secure_elf),
            tokio::fs::remove_file(&nonsecure_elf),
        );
        let _ = (ignore_not_found(r1)?, ignore_not_found(r2)?);

        // Build the benchmark
        log::info!("Building the program");
        let mut build_args = vec!["build".to_owned(), format!("build:{}", traits.name())];
        bo.append_zig_buld_opts_to(|o| {
            build_args.push(o.to_owned());
        });
        build_args.extend(target.zig_build_flags().iter().cloned().map(str::to_owned));

        subprocess::CmdBuilder::new(&opt.zig_cmd)
            .args(build_args.iter())
            .spawn_expecting_success()
            .await?;

        // Assert the existence of the built ELF images
        log::trace!(
            "Checking the existence of {:?} and {:?}",
            secure_elf,
            nonsecure_elf
        );
        if !secure_elf.exists() {
            return Err(RunBenchmarkError::BuiltExeNotFound(secure_elf).into());
        }
        if !nonsecure_elf.exists() {
            return Err(RunBenchmarkError::BuiltExeNotFound(nonsecure_elf).into());
        }

        // Copy the built ELF images
        let secure_elf_copied = output_dir.join(format!("{}.{}", bo, meta.exe_names.secure));
        let nonsecure_elf_copied = output_dir.join(format!("{}.{}", bo, meta.exe_names.non_secure));
        log::trace!(
            "Copying {:?} and {:?} to {:?} and {:?} (respectively)",
            secure_elf,
            nonsecure_elf,
            secure_elf_copied,
            nonsecure_elf_copied,
        );
        let (r1, r2) = tokio::join!(
            tokio::fs::copy(&secure_elf, &secure_elf_copied),
            tokio::fs::copy(&nonsecure_elf, &nonsecure_elf_copied),
        );
        (r1?, r2?);

        // Program the target board
        log::info!("Programming the target board");
        let t = AtomicRefCell::new(&mut target);
        retry_on_fail(|| async { t.borrow_mut().program(&[&nonsecure_elf, &secure_elf]).await })
            .await
            .map_err(RunBenchmarkError::ProgrammingError)?;

        // Run the program
        let t = AtomicRefCell::new(&mut *target);
        retry_on_fail(|| async {
            log::info!("Running the program");
            let markers = [b"unhandled exception", traits.output_terminator()];
            let output =
                target::target_reset_and_get_output_until(*&mut *t.borrow_mut(), markers.iter())
                    .await
                    .map_err(|e| RunBenchmarkError::OutputAcquisitionError(e.into()))?;

            // Save the raw output
            let save_path = output_dir.join(format!("{}.raw", bo));
            log::info!("Saving the raw output to {:?}", save_path);

            tokio::fs::write(&save_path, &output)
                .await
                .map_err(|e| RunBenchmarkError::WriteOutputError(e.into()))?;

            // Post-process the output
            log::info!("Post-processing the output");
            if let Some(output) = traits
                .process_output(&output)
                .map_err(|e| RunBenchmarkError::ProcessOutputError(e))?
            {
                // Save the processed output
                let save_path = output_dir.join(format!("{}.json", bo));
                log::info!("Saving the result to {:?}", save_path);

                tokio::fs::write(&save_path, output)
                    .await
                    .map_err(|e| RunBenchmarkError::WriteOutputError(e.into()))?;
            } else {
                log::info!("Post-processing yielded no results");
            }

            Ok::<(), Box<dyn Error>>(())
        })
        .await?;

        meta.matrix.push(MetaRun {
            build_opt: bo,
            name: bo.to_string(),
            zig_build_args: build_args,
        });
    }

    let meta_path = output_dir.join("meta.json");
    log::info!("Writing metadata to: {:?}", meta_path);
    {
        let json = serde_json::to_string_pretty(&meta).unwrap();
        tokio::fs::write(&meta_path, json).await?;
    }

    Ok(())
}

#[derive(Debug, Error)]
enum RunBenchmarkError {
    #[error("Could not create the output directory.\n\n{0}")]
    CreateOutputDirError(Box<dyn Error>),

    #[error("The builder did not produce the executable file {0:?}.")]
    BuiltExeNotFound(PathBuf),

    #[error("Could not program the target board.\n\n{0}")]
    ProgrammingError(Box<dyn Error>),

    #[error("Could not acquire the program output.\n\n{0}")]
    OutputAcquisitionError(Box<dyn Error>),

    #[error("Could not save the program output.\n\n{0}")]
    WriteOutputError(Box<dyn Error>),

    #[error("Could not post-process the output.\n\n{0}")]
    ProcessOutputError(Box<dyn Error>),
}

fn ignore_not_found(r: Result<(), std::io::Error>) -> Result<(), std::io::Error> {
    match r {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}

#[derive(Serialize)]
struct Metadata {
    benchmark: super::BenchmarkType,
    target: super::TargetType,
    exe_names: MetaExeNames,
    matrix: Vec<MetaRun>,
}

#[derive(Serialize)]
struct MetaExeNames {
    secure: String,
    non_secure: String,
}

#[derive(Serialize)]
struct MetaRun {
    build_opt: BuildOpt,
    name: String,
    zig_build_args: Vec<String>,
}

async fn retry_on_fail<R, T, E: std::fmt::Debug>(mut f: impl FnMut() -> R) -> Result<T, E>
where
    R: Future<Output = Result<T, E>>,
{
    let mut count = 3u32;
    loop {
        match f().await {
            Ok(x) => return Ok(x),
            Err(e) => {
                log::warn!("Attempt failed: {:?}", e);
                count -= 1;
                if count == 0 {
                    log::warn!("Retry limit reached");
                    return Err(e);
                } else {
                    log::warn!("Retrying... (remaining count = {:?})", count);
                }
            }
        }
    }
}
