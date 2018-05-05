//! Parser for the Arm (Advanced RISC Machine) instructions.
//!
//! It only supports the Armv8-M subset.
use std::collections::HashMap;
use std::fmt;
use unicase::UniCase;

use super::main::RawDirective;
use super::{Directive, GasDirective};

pub type ArmGasDirective<'a> = Directive<'a, ArmDirective<'a>>;

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum ArmDirective<'a> {
    /// Directives that we don't care, or are not supported.
    Misc(ArmMiscDirective, &'a str),
}

impl<'a> ArmGasDirective<'a> {
    pub fn from_raw_directive(raw_directive: &'a RawDirective<'a>) -> Result<Self, String> {
        Ok(
            // Too bad we have to call `<str>::to_owned()` here :(
            if let Some(handler) = MAP.get(&UniCase::new(raw_directive.key.to_owned())) {
                Directive::Target(handler.parse(raw_directive)?)
            } else {
                Directive::Gas(GasDirective::from_raw_directive(raw_directive)?)
            },
        )
    }
}

impl<'a> fmt::Display for ArmDirective<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            &ArmDirective::Misc(kind, rest) => write!(f, "{} {}", kind, rest),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum ArmMiscDirective {
    Adc,
}

impl ArmMiscDirective {
    pub fn as_str(&self) -> &'static str {
        match self {
            &ArmMiscDirective::Adc => "adc",
        }
    }
}

impl fmt::Display for ArmMiscDirective {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

trait DirectiveHandler: Sync + Send + 'static {
    fn key(&self) -> &str;
    fn parse<'a>(&self, directive: &'a RawDirective) -> Result<ArmDirective<'a>, String>;
}

lazy_static! {
    static ref MAP: HashMap<UniCase<String>, Box<DirectiveHandler>> =
        vec![Box::new(Misc(ArmMiscDirective::Adc)) as _]
            .into_iter()
            .map(|x: Box<DirectiveHandler>| (UniCase::new(x.key().to_owned()), x))
            .collect();
}

struct Misc(ArmMiscDirective);

impl DirectiveHandler for Misc {
    fn key(&self) -> &str {
        self.0.as_str()
    }

    fn parse<'a>(&self, directive: &'a RawDirective) -> Result<ArmDirective<'a>, String> {
        Ok(ArmDirective::Misc(self.0, directive.rest))
    }
}
