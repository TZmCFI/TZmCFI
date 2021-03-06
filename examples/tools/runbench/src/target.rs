//! Implements code for controlling the target.
use std::{error::Error, future::Future, path::Path, pin::Pin, time::Duration};
use thiserror::Error;
use tokio::{io::AsyncRead, prelude::*};

pub mod lpc55s69;
pub mod qemu;

#[derive(Error, Debug)]
pub enum RunError {
    #[error("Timeout while reading the output")]
    Timeout,
    #[error("Length limit exceeded while reading the output")]
    TooLong,
    #[error("{0}")]
    Other(
        #[from]
        #[source]
        Box<dyn Error>,
    ),
}

pub trait Target {
    /// The build flags to pass to `zig build`.
    fn zig_build_flags(&self) -> &[&str];

    /// Program the specified ELF images. Previous images may be erased. The
    /// actual operation may be deferred until `reset_and_get_output` is called.
    ///
    /// Warning: Be careful with this method - Flash memory has limited write
    /// cycles, so calling this method for many times may actually [kill] the
    /// target chip.
    ///
    /// [kill]: https://en.wikipedia.org/wiki/Killer_poke
    fn program(
        &mut self,
        paths: &[&Path],
    ) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn Error>>> + '_>>;

    /// Run the currently programmed application from the beginning and capture
    /// its output.
    fn reset_and_get_output(
        &mut self,
    ) -> Pin<Box<dyn Future<Output = Result<DynAsyncRead<'_>, Box<dyn Error>>> + '_>>;
}

type DynAsyncRead<'a> = Pin<Box<dyn AsyncRead + 'a>>;

/// Run the currently programmed application from the start and capture its
/// output until a marker is found.
pub async fn target_reset_and_get_output_until<P: AsRef<[u8]>>(
    target: &mut (impl Target + ?Sized),
    markers: impl IntoIterator<Item = P>,
) -> Result<Vec<u8>, RunError> {
    let mut stream = target.reset_and_get_output().await?;
    log::trace!("target_reset_and_get_output_until: Got a stream");

    let matcher = aho_corasick::AhoCorasickBuilder::new().build(markers);

    let mut output = Vec::new();
    let mut buffer = vec![0u8; 16384];

    loop {
        log::trace!("... calling `read`");
        let read_fut = stream.read(&mut buffer);
        let timeout_fut = tokio::time::delay_for(Duration::from_secs(35));

        let num_bytes = tokio::select! {
            read_result = read_fut => {
                log::trace!("... `read` resolved to {:?}", read_result);
                read_result.unwrap_or(0)
            },
            _ = timeout_fut => {
                log::trace!("... `delay_for` resolved earlier - timeout");
                log::trace!("... The output so far: {:?}", String::from_utf8_lossy(&output));
                return Err(RunError::Timeout);
            },
        };

        if num_bytes == 0 {
            break;
        }

        output.extend_from_slice(&buffer[0..num_bytes]);

        // Check for markers
        let check_len = (num_bytes + matcher.max_pattern_len() - 1).min(output.len());
        if output.len() >= check_len {
            let i = output.len() - check_len;
            if let Some(m) = matcher.find(&output[i..]) {
                log::trace!(
                    "... Found the marker at position {:?}",
                    i + m.start()..i + m.end()
                );
                output.truncate(i + m.end());
                break;
            }
        }

        if output.len() > 1024 * 1024 {
            return Err(RunError::TooLong);
        }
    }

    Ok(output)
}

/// Choose a serial port based on command-line options.
fn choose_serial(opt: &super::Opt) -> Result<String, ChooseSerialError> {
    if let Some(p) = &opt.serial_port {
        log::info!("Using the serial port {:?} (manually selected)", p);
        Ok(p.clone())
    } else {
        let ports = mio_serial::available_ports()?;
        log::trace!("Available ports: {:?}", ports);
        if ports.len() == 0 {
            return Err(ChooseSerialError::NoPortsAvailable);
        } else if ports.len() > 1 {
            return Err(ChooseSerialError::MultiplePortsAvailable(
                ports.into_iter().map(|i| i.port_name).collect(),
            ));
        }

        let p = ports.into_iter().next().unwrap().port_name;
        log::info!("Using the serial port {:?} (automatically selected)", p);
        Ok(p)
    }
}

#[derive(Error, Debug)]
enum ChooseSerialError {
    #[error("No serial ports were found")]
    NoPortsAvailable,
    #[error(
        "Multiple serial ports were found. \
        Please specify one of the following using `--serial`: {0:?}"
    )]
    MultiplePortsAvailable(Vec<String>),
    #[error("Could not enumerate serial ports.\n\n{0}")]
    SystemError(
        #[from]
        #[source]
        mio_serial::Error,
    ),
}
