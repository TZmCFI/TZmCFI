//! Parser for the GAS machine-independent assembler directives.
use std::collections::HashMap;
use std::fmt;

use super::main::RawDirective;

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum GasDirective<'a> {
    /// Directives that we don't care about its structure. e.g., `Misc(".align", "2")`,
    /// or those that we simply don't support yet
    Simple(GasSimpleDirective, &'a str),
}

impl<'a> GasDirective<'a> {
    pub fn from_raw_directive(raw_directive: &'a RawDirective<'a>) -> Result<Self, String> {
        if let Some(handler) = MAP.get(raw_directive.key) {
            handler.parse(raw_directive)
        } else {
            Err(format!("Unrecognized directive: '{}'", raw_directive.key))
        }
    }
}

impl<'a> fmt::Display for GasDirective<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            &GasDirective::Simple(kind, rest) => write!(f, "{} {}", kind, rest),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum GasSimpleDirective {
    Arch,
    Ascii,
    Align,
    CfiDefCfaOffset,
    CfiEndproc,
    CfiOffset,
    CfiRestore,
    CfiSections,
    CfiStartproc,
    Cpu,
    EabiAttribute,
    Extern,
    File,
    Fpu,
    Global,
    Ident,
    Loc,
    Section,
    Set,
    Size,
    Sleb128,
    Syntax,
    Text,
    Thumb,
    Thumbfunc,
    Type,
    Uleb128,
    Weak,

    Byte,
    Word,
    TwoByte,
    FourByte,
}

impl GasSimpleDirective {
    pub fn as_str(&self) -> &'static str {
        match self {
            &GasSimpleDirective::Arch => ".arch",
            &GasSimpleDirective::Ascii => ".ascii",
            &GasSimpleDirective::Align => ".align",
            &GasSimpleDirective::CfiDefCfaOffset => ".cfi_def_cfa_offset",
            &GasSimpleDirective::CfiEndproc => ".cfi_endproc",
            &GasSimpleDirective::CfiOffset => ".cfi_offset",
            &GasSimpleDirective::CfiRestore => ".cfi_restore",
            &GasSimpleDirective::CfiSections => ".cfi_sections",
            &GasSimpleDirective::CfiStartproc => ".cfi_startproc",
            &GasSimpleDirective::Cpu => ".cpu",
            &GasSimpleDirective::EabiAttribute => ".eabi_attribute",
            &GasSimpleDirective::Extern => ".extern",
            &GasSimpleDirective::File => ".file",
            &GasSimpleDirective::Fpu => ".fpu",
            &GasSimpleDirective::Global => ".global",
            &GasSimpleDirective::Ident => ".ident",
            &GasSimpleDirective::Loc => ".loc",
            &GasSimpleDirective::Section => ".section",
            &GasSimpleDirective::Set => ".set",
            &GasSimpleDirective::Size => ".size",
            &GasSimpleDirective::Sleb128 => ".sleb128",
            &GasSimpleDirective::Syntax => ".syntax",
            &GasSimpleDirective::Text => ".text",
            &GasSimpleDirective::Thumb => ".thumb",
            &GasSimpleDirective::Thumbfunc => ".thumb_func",
            &GasSimpleDirective::Type => ".type",
            &GasSimpleDirective::Uleb128 => ".uleb128",
            &GasSimpleDirective::Weak => ".weak",

            &GasSimpleDirective::Byte => ".byte",
            &GasSimpleDirective::Word => ".word",
            &GasSimpleDirective::TwoByte => ".2byte",
            &GasSimpleDirective::FourByte => ".4byte",
        }
    }
}

impl fmt::Display for GasSimpleDirective {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

trait DirectiveHandler: Sync + Send + 'static {
    fn key(&self) -> &str;
    fn parse<'a>(&self, directive: &'a RawDirective) -> Result<GasDirective<'a>, String>;
}

lazy_static! {
    static ref MAP: HashMap<String, Box<DirectiveHandler>> = vec![
        Box::new(Simple(GasSimpleDirective::Arch)) as _,
        Box::new(Simple(GasSimpleDirective::Ascii)) as _,
        Box::new(Simple(GasSimpleDirective::Align)) as _,
        Box::new(Simple(GasSimpleDirective::CfiDefCfaOffset)) as _,
        Box::new(Simple(GasSimpleDirective::CfiEndproc)) as _,
        Box::new(Simple(GasSimpleDirective::CfiOffset)) as _,
        Box::new(Simple(GasSimpleDirective::CfiRestore)) as _,
        Box::new(Simple(GasSimpleDirective::CfiSections)) as _,
        Box::new(Simple(GasSimpleDirective::CfiStartproc)) as _,
        Box::new(Simple(GasSimpleDirective::Cpu)) as _,
        Box::new(Simple(GasSimpleDirective::EabiAttribute)) as _,
        Box::new(Simple(GasSimpleDirective::Extern)) as _,
        Box::new(Simple(GasSimpleDirective::File)) as _,
        Box::new(Simple(GasSimpleDirective::Fpu)) as _,
        Box::new(Simple(GasSimpleDirective::Global)) as _,
        Box::new(Simple(GasSimpleDirective::Ident)) as _,
        Box::new(Simple(GasSimpleDirective::Loc)) as _,
        Box::new(Simple(GasSimpleDirective::Section)) as _,
        Box::new(Simple(GasSimpleDirective::Set)) as _,
        Box::new(Simple(GasSimpleDirective::Size)) as _,
        Box::new(Simple(GasSimpleDirective::Sleb128)) as _,
        Box::new(Simple(GasSimpleDirective::Syntax)) as _,
        Box::new(Simple(GasSimpleDirective::Text)) as _,
        Box::new(Simple(GasSimpleDirective::Thumb)) as _,
        Box::new(Simple(GasSimpleDirective::Thumbfunc)) as _,
        Box::new(Simple(GasSimpleDirective::Type)) as _,
        Box::new(Simple(GasSimpleDirective::Uleb128)) as _,
        Box::new(Simple(GasSimpleDirective::Weak)) as _,
        Box::new(Simple(GasSimpleDirective::Byte)) as _,
        Box::new(Simple(GasSimpleDirective::Word)) as _,
        Box::new(Simple(GasSimpleDirective::TwoByte)) as _,
        Box::new(Simple(GasSimpleDirective::FourByte)) as _,
    ].into_iter()
        .map(|x: Box<DirectiveHandler>| (x.key().to_owned(), x))
        .collect();
}

struct Simple(GasSimpleDirective);

impl DirectiveHandler for Simple {
    fn key(&self) -> &str {
        self.0.as_str()
    }

    fn parse<'a>(&self, directive: &'a RawDirective) -> Result<GasDirective<'a>, String> {
        Ok(GasDirective::Simple(self.0, directive.rest))
    }
}
