use std::{
    error::Error,
    ffi::OsStr,
    future::Future,
    path::{Path, PathBuf},
    pin::Pin,
};
use thiserror::Error;
use tokio_serial::{Serial, SerialPortSettings};

use super::{choose_serial, DynAsyncRead, Target};
use crate::subprocess;

/// Runs a program on a LPC55S69 target board.
pub struct Lpc55s69Target<'a> {
    pyocd_cmd: &'a OsStr,
    pyocd_uid: Option<&'a OsStr>,
    serial_port: String,
}

impl<'a> Lpc55s69Target<'a> {
    // `Self` can't used to write this return type because of
    // <https://github.com/rust-lang/rust/pull/62849>
    pub(crate) async fn new(opt: &'a crate::Opt) -> Result<Lpc55s69Target<'a>, Box<dyn Error>> {
        // Try launching pyocd
        let version_info = subprocess::CmdBuilder::new(&opt.pyocd_cmd)
            .arg("--version")
            .spawn_capturing_stdout()
            .await?;

        log::info!("PyOCD version: {:?}", String::from_utf8(version_info));

        // Find the serial port for reading output
        let serial_port = choose_serial(opt)?;

        Ok(Self {
            pyocd_cmd: &opt.pyocd_cmd,
            pyocd_uid: opt.pyocd_uid.as_deref(),
            serial_port,
        })
    }

    fn pyocd_uid_args(&self) -> impl Iterator<Item = &'_ OsStr> {
        if let Some(uid) = self.pyocd_uid {
            either::Either::Left(vec![OsStr::new("--uid"), uid].into_iter())
        } else {
            either::Either::Right(std::iter::empty())
        }
    }
}

impl Target for Lpc55s69Target<'_> {
    fn zig_build_flags(&self) -> &[&str] {
        &["-Dtarget-board=lpc55s69"]
    }

    fn program(
        &mut self,
        paths: &[&Path],
    ) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn Error>>> + '_>> {
        #[derive(Error, Debug)]
        enum LocalError {
            #[error("PyOCD returned an error while programming the target.\n\n{0}")]
            ProgramError(#[source] Box<dyn Error>),

            #[error("Could not get the absolute path = {0}.\n\n{1}")]
            PathError(PathBuf, #[source] Box<dyn Error>),
        }

        let paths: Vec<_> = paths.iter().map(|p| Path::to_owned(p)).collect();
        Box::pin(async move {
            for path in paths.iter() {
                let path = path
                    .canonicalize()
                    .map_err(|e| LocalError::PathError(path.clone(), e.into()))?;
                subprocess::CmdBuilder::new(&self.pyocd_cmd)
                    .arg("flash")
                    .arg("-t")
                    .arg("lpc55s69")
                    .args(self.pyocd_uid_args())
                    .arg("--format")
                    .arg("elf")
                    .arg(path)
                    .spawn_expecting_success()
                    .await
                    .map_err(|e| LocalError::ProgramError(e.into()))?;
            }

            Ok(())
        })
    }

    fn reset_and_get_output(
        &mut self,
    ) -> Pin<Box<dyn Future<Output = Result<DynAsyncRead<'_>, Box<dyn Error>>> + '_>> {
        #[derive(Error, Debug)]
        enum LocalError {
            #[error("PyOCD returned an error while halting the target.\n\n{0}")]
            HaltError(#[source] Box<dyn Error>),

            #[error("PyOCD returned an error while resetting the target.\n\n{0}")]
            ResetError(#[source] Box<dyn Error>),

            #[error("Could not open the serial port.\n\n{0}")]
            SerialError(#[source] Box<dyn Error>),
        }

        Box::pin(async move {
            // Halt the board
            subprocess::CmdBuilder::new(&self.pyocd_cmd)
                .arg("cmd")
                .arg("-t")
                .arg("lpc55s69")
                .args(self.pyocd_uid_args())
                .arg("-c")
                .arg("halt")
                .spawn_expecting_success()
                .await
                .map_err(|e| LocalError::HaltError(e.into()))?;

            // Open the serial port first
            let serial = Serial::from_path(
                &self.serial_port,
                &SerialPortSettings {
                    baud_rate: 115200,
                    timeout: std::time::Duration::from_secs(60),
                    ..Default::default()
                },
            )
            .map_err(|e| LocalError::SerialError(e.into()))?;

            // Reset the board
            subprocess::CmdBuilder::new(&self.pyocd_cmd)
                .arg("cmd")
                .arg("-t")
                .arg("lpc55s69")
                .args(self.pyocd_uid_args())
                .arg("-c")
                .arg("reset")
                .spawn_expecting_success()
                .await
                .map_err(|e| LocalError::ResetError(e.into()))?;

            Ok(Box::pin(serial) as DynAsyncRead<'_>)
        })
    }
}
