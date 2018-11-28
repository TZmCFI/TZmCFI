//! Provides a structure to represent an Arm (Advanced RISC Machine) instruction
//! and to inspect its properties.
//!
//! Note that we only support the Armv8-M subset.
mod format;
mod inst;
mod parse;
pub use self::format::*;
pub use self::inst::*;
pub use self::parse::*;
