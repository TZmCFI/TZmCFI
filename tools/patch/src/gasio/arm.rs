//! Parser for the Arm (Advanced RISC Machine) instructions.
//!
//! It only supports the Armv8-M subset.
use super::main::RawDirective;
use super::{Directive, GasDirective};
use arm::ArmDirective;

pub type ArmGasDirective<'a> = Directive<'a, ArmDirective<'a>>;

impl<'a> ArmGasDirective<'a> {
    pub fn from_raw_directive(raw_directive: &'a RawDirective<'a>) -> Result<Self, String> {
        if let Some(x) = ArmDirective::from_str(raw_directive.key, raw_directive.rest)? {
            Ok(Directive::Target(x))
        } else {
            Ok(Directive::Gas(GasDirective::from_raw_directive(
                raw_directive,
            )?))
        }
    }
}
