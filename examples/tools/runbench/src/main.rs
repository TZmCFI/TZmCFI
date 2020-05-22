use std::{error::Error, ffi::OsString, fmt, path::PathBuf};
use structopt::StructOpt;
use thiserror::Error;

mod bench_rtos;
mod subprocess;
mod target;

/// Runs a benchmark automatically under various build configurations.
///
/// Note: This program must be run in the `examples` directory.
#[derive(StructOpt)]
#[structopt(name = "tzmcfi_runbench")]
struct Opt {
    /// Benchmark to run
    #[structopt(
        possible_values(&BenchmarkType::variants()), case_insensitive = true
    )]
    benchmark: BenchmarkType,

    /// Target to run the benchmark on
    #[structopt(
        short = "t", long = "target",
        possible_values(&TargetType::variants()), case_insensitive = true
    )]
    target: TargetType,

    /// Path to the `zig-cache` directory, in which `zig build` stores built
    /// artifacts
    #[structopt(
        long = "zig-cache-dir",
        default_value = "zig-cache",
        parse(from_os_str),
        env = "ZIG_CACHE_DIR"
    )]
    zig_cache_dir: PathBuf,

    /// Path to save results in
    #[structopt(short = "o", long = "output-dir", parse(from_os_str))]
    output: PathBuf,

    /// Command to invoke the Zig compiler
    #[structopt(long = "zig", default_value = "zig", parse(from_os_str), env = "ZIG")]
    zig_cmd: OsString,

    /// Command to invoke PyOCD
    #[structopt(
        long = "pyocd",
        default_value = "pyocd",
        parse(from_os_str),
        env = "PYOCD"
    )]
    pyocd_cmd: OsString,

    /// Command to invoke QEMU
    #[structopt(
        long = "qemu",
        default_value = "qemu-system-arm",
        parse(from_os_str),
        env = "QEMU"
    )]
    qemu_system_arm_cmd: OsString,
}

#[derive(arg_enum_proc_macro::ArgEnum)]
enum BenchmarkType {
    Rtos,
    Latency,
    CoreMark,
}

#[derive(arg_enum_proc_macro::ArgEnum)]
enum TargetType {
    Qemu,
    Lpc55s69,
}

#[tokio::main]
async fn main() {
    env_logger::from_env(env_logger::Env::default().default_filter_or("info")).init();

    // Parse command-line arguments
    let opt = Opt::from_args();

    let result = match opt.benchmark {
        BenchmarkType::Rtos => {
            run_non_secure_runtime_benchmark(&opt, bench_rtos::RtosBenchmarkTraits).await
        }
        _ => todo!(),
    };

    if let Err(e) = result {
        log::error!("Command failed.\n\n{}", e);
    }
}

#[derive(Error, Debug)]
#[error("Could not initialize the target driver.\n\n{0}")]
struct BuildTargetError(
    #[from]
    #[source]
    Box<dyn Error>,
);

async fn build_target(opt: &Opt) -> Result<Box<dyn target::Target + '_>, BuildTargetError> {
    match opt.target {
        TargetType::Qemu => Ok(Box::new(
            target::qemu::QemuTarget::new(&opt)
                .await
                .map_err(|e| Box::new(e) as Box<dyn Error>)?,
        )),
        TargetType::Lpc55s69 => todo!(),
    }
}

/// Describes the traits of a Non-Secure benchmark application for measuring
/// an execution time.
trait NonSecureRuntimeBenchmarkTraits {
    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of shadow exception stacks.
    fn should_use_shadow_exception_stacks(&self) -> bool;

    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of shadow stacks.
    fn should_use_shadow_stacks(&self) -> bool;

    /// Return a flag indicating whether the test conditions for this benchmark
    /// should include the use of the context management API.
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

async fn run_non_secure_runtime_benchmark(
    opt: &Opt,
    traits: impl NonSecureRuntimeBenchmarkTraits,
) -> Result<(), Box<dyn Error>> {
    let mut target = build_target(opt).await?;

    let build_opts = BuildOpt::all_valid_values().filter(|bo| {
        if !traits.should_use_shadow_exception_stacks() && bo.ses {
            return false;
        }
        if !traits.should_use_shadow_stacks() && bo.ss {
            return false;
        }
        if !traits.should_use_context_management() && bo.ctx {
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

    log::info!("The output will be saved to: {:?}", opt.output);
    tokio::fs::create_dir_all(&opt.output)
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
        let save_path = opt.output.join(format!("{}.txt", bo));
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

/// The build options defined by `build.zig`
#[derive(Debug, Clone, Copy)]
struct BuildOpt {
    mode: BuildMode,
    ctx: bool,
    ses: bool,
    ss: bool,
    aborting_ss: bool,
    icall: bool,
    accel_raise_pri: bool,
}

#[derive(Debug, Clone, Copy)]
enum BuildMode {
    ReleaseFast,
    ReleaseSmall,
}

impl fmt::Display for BuildOpt {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{:?} ", self.mode)?;

        let mut emitted = false;

        macro_rules! e {
            ($($tt:tt)*) => {{
                if emitted {
                    write!(f, "+")?;
                }
                emitted = true;
                write!(f, $($tt)*)?;
            }};
        }

        if self.ctx {
            e!("ctx");
        }
        if self.ses {
            e!("ses");
        }
        if self.ss {
            if self.aborting_ss {
                e!("ss(aborting)");
            } else {
                e!("ss(non-aborting)");
            }
        }
        if self.icall {
            e!("icall");
        }
        if self.accel_raise_pri {
            e!("ape");
        }
        if !emitted {
            write!(f, "baseline")?;
        }
        Ok(())
    }
}

impl BuildOpt {
    fn all_valid_values() -> impl Iterator<Item = Self> + Clone {
        use itertools::iproduct;
        iproduct!(
            [BuildMode::ReleaseFast, BuildMode::ReleaseSmall]
                .iter()
                .cloned(),
            [false, true].iter().cloned(),
            [false, true].iter().cloned(),
            [false, true].iter().cloned(),
            [false, true].iter().cloned(),
            [false, true].iter().cloned(),
            [false, true].iter().cloned()
        )
        .map(|c| Self {
            mode: c.0,
            ctx: c.1,
            ses: c.2,
            ss: c.3,
            aborting_ss: c.4,
            icall: c.5,
            accel_raise_pri: c.6,
        })
        .filter(|o| o.validate().is_ok())
    }

    fn validate(&self) -> Result<(), &'static str> {
        if self.ss && !self.ctx {
            // Shadow stacks are managed by context management API.
            return Err("cfi-ss requires cfi-ctx");
        }

        if self.ses && !self.ctx {
            // Shadow exception stacks are managed by context management API.
            return Err("cfi-ses requires cfi-ctx");
        }

        if self.ss && !self.ses {
            // TZmCFI's shadow stacks do not work without shadow exception stacks.
            // Probably because the shadow stack routines mess up the lowest bit
            // of `EXC_RETURN`.
            return Err("cfi-ss requires cfi-ses");
        }

        if self.aborting_ss && !self.ss {
            // `aborting_ss` makes no sense without `ss`
            return Err("aborting-ss requires cfi-ss");
        }

        if self.accel_raise_pri && !self.ctx {
            // `TCRaisePrivilege` is a Secure function, so each thread needs its own
            // Secure stack
            return Err("-Daccel-raise-pri requires -Dcfi-ctx");
        }

        Ok(())
    }

    fn append_zig_buld_opts_to(&self, mut o: impl FnMut(&'static str)) {
        match self.mode {
            BuildMode::ReleaseFast => o("-Drelease-fast"),
            BuildMode::ReleaseSmall => o("-Drelease-small"),
        }
        o("-Dcfi=false");
        if self.ctx {
            o("-Dcfi-ctx");
        }
        if self.ses {
            o("-Dcfi-ses");
        }
        if self.ss {
            o("-Dcfi-ss");
        }
        if self.aborting_ss {
            o("-Dcfi-aborting-ss");
        }
        if self.icall {
            o("-Dcfi-icall");
        }
        if self.accel_raise_pri {
            o("-Daccel-raise-pri");
        }
    }
}
