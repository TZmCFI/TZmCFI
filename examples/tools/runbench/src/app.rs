use std::{error::Error, path::PathBuf};
use thiserror::Error;

use super::{build_target, subprocess, target, BuildOpt};

pub mod bench_coremark;
pub mod bench_latency;
pub mod bench_rtos;

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
    fn output_terminator(&self) -> &[u8];
}

pub(crate) async fn run(opt: &super::Opt, traits: impl AppTraits) -> Result<(), Box<dyn Error>> {
    let mut target = build_target(opt).await?;

    let build_opts = BuildOpt::all_valid_values().filter(|bo| {
        if !traits.should_use_shadow_exception_stacks() && !bo.ses {
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

        // Program the target board
        target
            .program(&[&nonsecure_elf, &secure_elf])
            .await
            .map_err(RunBenchmarkError::ProgrammingError)?;

        // Run the program
        log::info!("Running the program");
        let markers = [b"unhandled exception", traits.output_terminator()];
        let output = target::target_reset_and_get_output_until(&mut *target, markers.iter())
            .await
            .map_err(|e| RunBenchmarkError::OutputAcquisitionError(e.into()))?;

        // Save the output
        let save_path = output_dir.join(format!("{}.txt", bo));
        log::info!("Saving the result to {:?}", save_path);

        tokio::fs::write(&save_path, output)
            .await
            .map_err(|e| RunBenchmarkError::WriteOutputError(e.into()))?;
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
}

fn ignore_not_found(r: Result<(), std::io::Error>) -> Result<(), std::io::Error> {
    match r {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}
