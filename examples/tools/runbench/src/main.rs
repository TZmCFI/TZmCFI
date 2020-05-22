use std::{error::Error, ffi::OsString, fmt, path::PathBuf};
use structopt::StructOpt;
use thiserror::Error;

mod app;
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
    #[structopt(
        short = "o",
        long = "output-dir",
        default_value = "runbench.artifacts/%date%-%time%-%benchmark%"
    )]
    output_dir_template: String,

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

impl Opt {
    /// Replace variables in `output_dir_template` and form the final output
    /// directory path.
    ///
    /// Warning: The result changes every time you call this method.
    fn output_dir(&self) -> PathBuf {
        use chrono::prelude::*;
        let now = Local::now();

        self.output_dir_template
            .replace("%date%", &now.format("%Y%m%d").to_string())
            .replace("%time%", &now.format("%H%M%S").to_string())
            .replace("%benchmark%", &self.benchmark.to_string())
            .into()
    }
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
        BenchmarkType::Rtos => app::run(&opt, app::bench_rtos::BenchRtosTraits).await,
        BenchmarkType::Latency => app::run(&opt, app::bench_latency::BenchLatencyTraits).await,
        BenchmarkType::CoreMark => app::run(&opt, app::bench_coremark::BenchCoreMarkTraits).await,
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
