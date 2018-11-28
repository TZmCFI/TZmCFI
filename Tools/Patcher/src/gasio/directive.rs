//! Parser for the GAS machine-independent assembler directives.
use std::collections::HashMap;
use std::fmt;

use super::main::RawDirective;

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum GasDirective<'a> {
    /// Directives that we don't care about its structure. e.g., `Misc(".align", "2")`,
    /// or those that we simply don't support yet
    Misc(GasMiscDirective, &'a str),
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
            &GasDirective::Misc(kind, rest) => write!(f, "{} {}", kind, rest),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum GasMiscDirective {
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

impl GasMiscDirective {
    pub fn as_str(&self) -> &'static str {
        match self {
            &GasMiscDirective::Arch => ".arch",
            &GasMiscDirective::Ascii => ".ascii",
            &GasMiscDirective::Align => ".align",
            &GasMiscDirective::CfiDefCfaOffset => ".cfi_def_cfa_offset",
            &GasMiscDirective::CfiEndproc => ".cfi_endproc",
            &GasMiscDirective::CfiOffset => ".cfi_offset",
            &GasMiscDirective::CfiRestore => ".cfi_restore",
            &GasMiscDirective::CfiSections => ".cfi_sections",
            &GasMiscDirective::CfiStartproc => ".cfi_startproc",
            &GasMiscDirective::Cpu => ".cpu",
            &GasMiscDirective::EabiAttribute => ".eabi_attribute",
            &GasMiscDirective::Extern => ".extern",
            &GasMiscDirective::File => ".file",
            &GasMiscDirective::Fpu => ".fpu",
            &GasMiscDirective::Global => ".global",
            &GasMiscDirective::Ident => ".ident",
            &GasMiscDirective::Loc => ".loc",
            &GasMiscDirective::Section => ".section",
            &GasMiscDirective::Set => ".set",
            &GasMiscDirective::Size => ".size",
            &GasMiscDirective::Sleb128 => ".sleb128",
            &GasMiscDirective::Syntax => ".syntax",
            &GasMiscDirective::Text => ".text",
            &GasMiscDirective::Thumb => ".thumb",
            &GasMiscDirective::Thumbfunc => ".thumb_func",
            &GasMiscDirective::Type => ".type",
            &GasMiscDirective::Uleb128 => ".uleb128",
            &GasMiscDirective::Weak => ".weak",

            &GasMiscDirective::Byte => ".byte",
            &GasMiscDirective::Word => ".word",
            &GasMiscDirective::TwoByte => ".2byte",
            &GasMiscDirective::FourByte => ".4byte",
        }
    }
}

impl fmt::Display for GasMiscDirective {
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
        Box::new(Misc(GasMiscDirective::Arch)) as _,
        Box::new(Misc(GasMiscDirective::Ascii)) as _,
        Box::new(Misc(GasMiscDirective::Align)) as _,
        Box::new(Misc(GasMiscDirective::CfiDefCfaOffset)) as _,
        Box::new(Misc(GasMiscDirective::CfiEndproc)) as _,
        Box::new(Misc(GasMiscDirective::CfiOffset)) as _,
        Box::new(Misc(GasMiscDirective::CfiRestore)) as _,
        Box::new(Misc(GasMiscDirective::CfiSections)) as _,
        Box::new(Misc(GasMiscDirective::CfiStartproc)) as _,
        Box::new(Misc(GasMiscDirective::Cpu)) as _,
        Box::new(Misc(GasMiscDirective::EabiAttribute)) as _,
        Box::new(Misc(GasMiscDirective::Extern)) as _,
        Box::new(Misc(GasMiscDirective::File)) as _,
        Box::new(Misc(GasMiscDirective::Fpu)) as _,
        Box::new(Misc(GasMiscDirective::Global)) as _,
        Box::new(Misc(GasMiscDirective::Ident)) as _,
        Box::new(Misc(GasMiscDirective::Loc)) as _,
        Box::new(Misc(GasMiscDirective::Section)) as _,
        Box::new(Misc(GasMiscDirective::Set)) as _,
        Box::new(Misc(GasMiscDirective::Size)) as _,
        Box::new(Misc(GasMiscDirective::Sleb128)) as _,
        Box::new(Misc(GasMiscDirective::Syntax)) as _,
        Box::new(Misc(GasMiscDirective::Text)) as _,
        Box::new(Misc(GasMiscDirective::Thumb)) as _,
        Box::new(Misc(GasMiscDirective::Thumbfunc)) as _,
        Box::new(Misc(GasMiscDirective::Type)) as _,
        Box::new(Misc(GasMiscDirective::Uleb128)) as _,
        Box::new(Misc(GasMiscDirective::Weak)) as _,
        Box::new(Misc(GasMiscDirective::Byte)) as _,
        Box::new(Misc(GasMiscDirective::Word)) as _,
        Box::new(Misc(GasMiscDirective::TwoByte)) as _,
        Box::new(Misc(GasMiscDirective::FourByte)) as _,
    ].into_iter()
        .map(|x: Box<DirectiveHandler>| (x.key().to_owned(), x))
        .collect();
}

struct Misc(GasMiscDirective);

impl DirectiveHandler for Misc {
    fn key(&self) -> &str {
        self.0.as_str()
    }

    fn parse<'a>(&self, directive: &'a RawDirective) -> Result<GasDirective<'a>, String> {
        Ok(GasDirective::Misc(self.0, directive.rest))
    }
}
