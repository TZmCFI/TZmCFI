use std::{
    error::Error,
    ffi::OsStr,
    future::Future,
    path::{Path, PathBuf},
    pin::Pin,
};

use super::{DynAsyncRead, Target};
use crate::subprocess;

/// Emulates Arm MPS2+ AN505 using `qemu-system-arm`.
pub struct QemuTarget<'a> {
    cmd: &'a OsStr,
    images: Vec<PathBuf>,
}

impl<'a> QemuTarget<'a> {
    // `Self` can't used to write this return type because of
    // <https://github.com/rust-lang/rust/pull/62849>
    pub(crate) async fn new(
        opt: &'a crate::Opt,
    ) -> Result<QemuTarget<'a>, subprocess::SubprocessError> {
        // Try launching qemu
        let version_info = subprocess::CmdBuilder::new(&opt.qemu_system_arm_cmd)
            .arg("--version")
            .spawn_capturing_stdout()
            .await?;

        log::info!("QEMU version info: {:?}", String::from_utf8(version_info));

        Ok(Self {
            cmd: &opt.qemu_system_arm_cmd,
            images: Vec::new(),
        })
    }
}

impl Target for QemuTarget<'_> {
    fn zig_build_flags(&self) -> &[&str] {
        &["-Dtarget-board=an505"]
    }

    fn program(
        &mut self,
        paths: &[&Path],
    ) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn Error>>> + '_>> {
        self.images.clear();
        self.images.extend(paths.iter().map(|p| Path::to_owned(p)));

        Box::pin(futures::future::ok(()))
    }

    fn reset_and_get_output(
        &mut self,
    ) -> Pin<Box<dyn Future<Output = Result<DynAsyncRead<'_>, Box<dyn Error>>> + '_>> {
        Box::pin(async move {
            let mut cmd_builder = subprocess::CmdBuilder::new(self.cmd)
                .arg("-machine")
                .arg("mps2-an505")
                .arg("-nographic")
                .arg("-d")
                .arg("guest_errors")
                .arg("-semihosting")
                .arg("-semihosting-config")
                .arg("target=native")
                .arg("-kernel")
                .arg(&self.images[0]);
            for image in self.images[1..].iter() {
                let mut dev: std::ffi::OsString = "loader,file=".into();
                dev.push(image);
                cmd_builder = cmd_builder.arg("-device").arg(dev);
            }

            let child = cmd_builder.spawn_and_get_child()?;
            Ok(Box::pin(OutputReader {
                // If we drop `Child` here and take only `child.stdout`, the
                // process will be killed
                child,
            }) as DynAsyncRead<'_>)
        })
    }
}

struct OutputReader {
    child: tokio::process::Child,
}

impl tokio::io::AsyncRead for OutputReader {
    fn poll_read(
        mut self: Pin<&mut Self>,
        cx: &mut std::task::Context,
        buf: &mut [u8],
    ) -> std::task::Poll<std::io::Result<usize>> {
        tokio::io::AsyncRead::poll_read(Pin::new(self.child.stdout.as_mut().unwrap()), cx, buf)
    }
}
