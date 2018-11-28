//! Parser for the Arm (Advanced RISC Machine) instructions.
//!
//! It only supports the Armv8-M subset.
use std::collections::HashMap;
use std::sync::Arc;
use unicase::UniCase;

use super::*;

impl Gpr {
    pub fn from_str(x: &str) -> Option<Self> {
        GPR_MAP.get(&UniCase::new(x)).cloned()
    }
}

lazy_static! {
    static ref GPR_MAP: HashMap<UniCase<&'static str>, Gpr> = vec![
        (UniCase::new("r0"), Gpr(0)),
        (UniCase::new("r1"), Gpr(1)),
        (UniCase::new("r2"), Gpr(2)),
        (UniCase::new("r3"), Gpr(3)),
        (UniCase::new("r4"), Gpr(4)),
        (UniCase::new("r5"), Gpr(5)),
        (UniCase::new("r6"), Gpr(6)),
        (UniCase::new("r7"), Gpr(7)),
        (UniCase::new("r8"), Gpr(8)),
        (UniCase::new("r9"), Gpr(9)),
        (UniCase::new("r10"), Gpr(10)),
        (UniCase::new("r11"), Gpr(11)),
        (UniCase::new("r12"), Gpr(12)),
        (UniCase::new("r13"), Gpr(13)),
        (UniCase::new("r14"), Gpr(14)),
        (UniCase::new("r15"), Gpr(15)),
        (UniCase::new("sp"), Gpr(13)),
        (UniCase::new("lr"), Gpr(14)),
        (UniCase::new("pc"), Gpr(15)),
    ].into_iter()
        .collect();
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum ArmDirective<'a> {
    /// An instruction that we recognize.
    Inst(Inst<&'a str>),
    /// Directives that we don't care, or are not supported.
    Misc(ArmMiscDirective, Cond, &'a str),
}

impl<'a> ArmDirective<'a> {
    pub fn from_str(key: &'a str, rest: &'a str) -> Result<Option<Self>, String> {
        Ok(
            // Too bad we have to call `<str>::to_owned()` here :(
            if let Some((handler, cond)) = MAP.get(&UniCase::new(key.to_owned())) {
                Some(handler.parse(key, rest, *cond)?)
            } else {
                None
            },
        )
    }
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum ArmMiscDirective {
    Adc,
}

trait DirectiveHandler: Sync + Send + 'static {
    fn key(&self) -> &str;
    fn accepts_cond(&self) -> bool {
        true
    }
    fn parse<'a>(
        &self,
        key: &'a str,
        rest: &'a str,
        cond: Cond,
    ) -> Result<ArmDirective<'a>, String>;
}

lazy_static! {
    static ref MAP: HashMap<UniCase<String>, (Arc<DirectiveHandler>, Cond)> = vec![
        Arc::new(Misc(ArmMiscDirective::Adc, true)) as _,
        Arc::new(BranchLabel(false)) as _,
        Arc::new(BranchLabel(true)) as _,
    ].into_iter()
        .flat_map(|x: Arc<DirectiveHandler>| {
            // Incorporate the condition flags into the instruction table
            if x.accepts_cond() {
                [
                    (Cond::Equal, "eq"),
                    (Cond::NotEqual, "ne"),
                    (Cond::CarrySet, "cs"),
                    (Cond::CarryClear, "cc"),
                    (Cond::Minus, "mi"),
                    (Cond::Plus, "pl"),
                    (Cond::Overflow, "vs"),
                    (Cond::NoOverflow, "vc"),
                    (Cond::UnsignedGreaterThanOrEqual, "hi"),
                    (Cond::UnsignedLessThan, "ls"),
                    (Cond::SignedGreaterThanOrEqual, "ge"),
                    (Cond::SignedLessThan, "lt"),
                    (Cond::SignedGreaterThan, "gt"),
                    (Cond::SignedLessThanOrEqual, "le"),
                    (Cond::CarrySet, "hs"),
                    (Cond::CarryClear, "lo"),
                    (Cond::None, "al"),
                    (Cond::None, ""),
                ].iter().map(|&(cond, cond_s)| (UniCase::new([x.key(), cond_s].concat()), (x.clone(), cond)))
                    .collect::<Vec<_>>()
            } else {
                vec![(UniCase::new(x.key().to_owned()), (x, Cond::None))]
            }
        })
        .collect();
}

struct Misc(ArmMiscDirective, bool);

impl DirectiveHandler for Misc {
    fn key(&self) -> &str {
        self.0.as_str()
    }
    fn accepts_cond(&self) -> bool {
        self.1
    }
    fn parse<'a>(
        &self,
        _key: &'a str,
        rest: &'a str,
        cond: Cond,
    ) -> Result<ArmDirective<'a>, String> {
        Ok(ArmDirective::Misc(self.0, cond, rest))
    }
}

mod parsing {
    use super::*;

    fn is_symbol_char(x: char) -> bool {
        x.is_alphanumeric() || x == '.' || x == '_' || x == '$'
    }
    named!(symbol_no_ws<&str, &str>, take_while1!(is_symbol_char));
    named!(pub symbol<&str, &str>, ws!(symbol_no_ws));

    named!(gpr<&str, Gpr>, map_opt!(symbol, Gpr::from_str));

    fn is_imm_char(x: char) -> bool {
        x.is_ascii_digit() || x == '-'
    }
    named!(imm<&str, &str>, preceded!(char!('#'), take_while1!(is_imm_char)));

    named!(value_imm_or_gpr<&str, Value<&str>>, ws!(alt_complete!(
        map!(imm, Value::Imm) |
        map!(gpr, Value::Gpr)
    )));
}

use nom::IResult;
fn map_iresult<O>(x: IResult<&str, O>) -> Result<O, String> {
    match x {
        IResult::Done(_, output) => Ok(output),
        IResult::Incomplete(_) => Err("unexpected EOF".to_owned()),
        IResult::Error(e) => Err(format!("failed to parse {:?}", e)),
    }
}

struct BranchLabel(bool);

impl DirectiveHandler for BranchLabel {
    fn key(&self) -> &str {
        if self.0 {
            "bl"
        } else {
            "b"
        }
    }
    fn parse<'a>(
        &self,
        _key: &'a str,
        rest: &'a str,
        cond: Cond,
    ) -> Result<ArmDirective<'a>, String> {
        let label = map_iresult(parsing::symbol(rest))?;
        Ok(ArmDirective::Inst(Inst {
            kind: InstKind::Branch {
                target: Value::Label(label),
                link: self.0,
                nonsecure: false,
            },
            cond,
        }))
    }
}
