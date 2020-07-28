use serde::Serialize;
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

    /// Include `-Drom-offset=N` in the test condition set
    #[structopt(long = "vary-rom-offset")]
    vary_rom_offset: bool,

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
        default_value = "runbench.artifacts/%date%-%time%-%target%-%benchmark%"
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

    /// PyOCD probe ID (`--uid`). Use `pyocd list` to list available probes
    #[structopt(long = "pyocd-uid", parse(from_os_str), env = "PYOCD_UID")]
    pyocd_uid: Option<OsString>,

    /// Serial port for communicating with a target board
    #[structopt(long = "serial", env = "SERIAL")]
    serial_port: Option<String>,

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
            .replace("%target%", &self.target.to_string())
            .replace("%benchmark%", &self.benchmark.to_string())
            .into()
    }
}

#[derive(Clone, Copy, arg_enum_proc_macro::ArgEnum, Serialize)]
enum BenchmarkType {
    Rtos,
    Latency,
    CoreMark,
    ProfileSes,
    ProfileRtos,
}

#[derive(Clone, Copy, arg_enum_proc_macro::ArgEnum, Serialize)]
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
        BenchmarkType::ProfileSes => app::run(&opt, app::profile_ses::ProfileSesTraits).await,
        BenchmarkType::ProfileRtos => app::run(&opt, app::profile_rtos::ProfileRtosTraits).await,
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
        TargetType::Lpc55s69 => Ok(Box::new(target::lpc55s69::Lpc55s69Target::new(&opt).await?)),
        TargetType::Qemu => Ok(Box::new(
            target::qemu::QemuTarget::new(&opt)
                .await
                .map_err(|e| Box::new(e) as Box<dyn Error>)?,
        )),
    }
}

/// The build options defined by `build.zig`
#[derive(Debug, Clone, Copy, Serialize)]
struct BuildOpt {
    mode: BuildMode,
    ctx: bool,
    ses: bool,
    ss: bool,
    aborting_ss: bool,
    icall: bool,
    accel_raise_pri: bool,
    unnest: bool,
    rom_offset: u8,
}

#[derive(Debug, Clone, Copy, Serialize)]
enum BuildMode {
    ReleaseFast,
    ReleaseSmall,
}

impl fmt::Display for BuildOpt {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{:?}", self.mode)?;

        macro_rules! e {
            ($($tt:tt)*) => {{
                write!(f, "+")?;
                write!(f, $($tt)*)?;
            }};
        }

        if self.ctx {
            e!("ctx");
        }
        if self.ses {
            if self.unnest {
                e!("ses(unnest)");
            } else {
                e!("ses");
            }
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
        if self.rom_offset != 0 {
            e!("off({})", self.rom_offset);
        }
        Ok(())
    }
}

impl BuildOpt {
    fn all_valid_values(opt: &Opt) -> impl Iterator<Item = Self> + Clone {
        use itertools::iproduct;
        // `iproduct!` can'be used with more than 8 iterators
        // <https://github.com/rust-itertools/itertools/issues/384>
        iproduct!(
            iproduct!(
                [BuildMode::ReleaseFast, BuildMode::ReleaseSmall]
                    .iter()
                    .cloned(),
                [false, true].iter().cloned(),
                [false, true].iter().cloned(),
                [false, true].iter().cloned(),
                [false, true].iter().cloned()
            ),
            [false, true].iter().cloned(),
            [false, true].iter().cloned(),
            [false, true].iter().cloned(),
            if opt.vary_rom_offset {
                &[0, 4, 8, 12][..]
            } else {
                &[0][..]
            }
            .iter()
            .cloned()
        )
        .map(
            |((mode, ctx, ses, unnest, ss), aborting_ss, icall, accel_raise_pri, rom_offset)| {
                Self {
                    mode,
                    ctx,
                    ses,
                    unnest,
                    ss,
                    aborting_ss,
                    icall,
                    accel_raise_pri,
                    rom_offset,
                }
            },
        )
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

        if self.unnest && !self.ses {
            // `unnest` makes no sense without `ses`
            return Err("-Dcfi-unnest requires -Dcfi-ses");
        }

        Ok(())
    }

    fn append_zig_buld_opts_to(&self, mut o: impl FnMut(String)) {
        match self.mode {
            BuildMode::ReleaseFast => o("-Drelease-fast".to_owned()),
            BuildMode::ReleaseSmall => o("-Drelease-small".to_owned()),
        }
        o("-Dcfi=false".to_owned());
        if self.ctx {
            o("-Dcfi-ctx".to_owned());
        }
        if self.ses {
            o("-Dcfi-ses".to_owned());
        }
        if self.unnest {
            o("-Dcfi-unnest".to_owned());
        }
        if self.ss {
            o("-Dcfi-ss".to_owned());
        }
        if self.aborting_ss {
            o("-Dcfi-aborting-ss".to_owned());
        }
        if self.icall {
            o("-Dcfi-icall".to_owned());
        }
        if self.accel_raise_pri {
            o("-Daccel-raise-pri".to_owned());
        } else {
            o("-Daccel-raise-pri=false".to_owned());
        }
        if self.rom_offset != 0 {
            o(format!("-Drom-offset={}", self.rom_offset));
        }
    }
}
