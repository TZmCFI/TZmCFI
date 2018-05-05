//! This module is an incomplete implementation of a parser for the GNU
//! assembler syntax, only enough for parsing a compiler's output.
//!
//! The grammar is roughly derived from [the GAS documentation] and does not
//! likely match its actual syntax.
//!
//! [the GAS documentation]: https://sourceware.org/binutils/docs/as/
pub mod arm;
mod common;
mod directive;
mod main;

pub use self::directive::*;
pub use self::main::*;

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum Directive<'a, T> {
    Gas(GasDirective<'a>),
    Target(T),
}

impl<'a, T> From<GasDirective<'a>> for Directive<'a, T> {
    fn from(x: GasDirective<'a>) -> Self {
        Directive::Gas(x)
    }
}
