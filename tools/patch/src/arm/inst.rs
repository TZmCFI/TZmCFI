use utils::int::*;

/// Represents a general-purpose register. Must be in range `[0, 15]`.
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Clone, Copy, Hash)]
pub struct Gpr(pub u8);

/// Represents a set of general-purpose registers.
#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub struct GprSet(pub u32);

impl GprSet {
    pub fn unique(&self) -> Option<Gpr> {
        let i = self.0.bit_scan_forward(0);
        if i < 32 && self.0 == (1u32 << i) {
            Some(Gpr(i as _))
        } else {
            None
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = Gpr> {
        self.0.one_digits().map(|x| Gpr(x as _))
    }
}

impl From<Gpr> for GprSet {
    fn from(x: Gpr) -> Self {
        GprSet(1 << x.0 as u32)
    }
}

/// Represents a conditional execution code (See Armv8-M ARM "C1.3 Conditional
/// execution").
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Clone, Copy, Hash)]
#[repr(u8)]
pub enum Cond {
    Equal = 0,
    NotEqual = 1,
    CarrySet = 2,
    CarryClear = 3,
    Minus = 4,
    Plus = 5,
    Overflow = 6,
    NoOverflow = 7,
    UnsignedGreaterThanOrEqual = 8,
    UnsignedLessThan = 9,
    SignedGreaterThanOrEqual = 10,
    SignedLessThan = 11,
    SignedGreaterThan = 12,
    SignedLessThanOrEqual = 13,
    None = 14,
}

impl Cond {
    pub fn from_value(x: u32) -> Option<Self> {
        use std::mem::transmute;
        if x < 15 {
            Some(unsafe { transmute(x as u8) })
        } else {
            None
        }
    }
}

/// Represents an Arm instruction (possibly undefined or unrealizable).
#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub struct Inst<T> {
    pub kind: InstKind<T>,
    pub cond: Cond,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum InstKind<T> {
    ///   - `B<ns>` - `{target: BrTarget::Imm(_), link: false, nonsecure: _}`
    ///   - `BL<ns>` - `{target: BrTarget::Imm(_), link: true, nonsecure: _}`
    ///   - `BX<ns>` - `{target: BrTarget::Reg(_), link: false, nonsecure: _}`
    ///   - `BLX<ns>` - `{target: BrTarget::Reg(_), link: true, nonsecure: _}`
    Branch {
        target: Value<T>,
        link: bool,
        nonsecure: bool,
    },
    ///   - `LDR` - `{address: _, disp: _, write_back: _, set: _ /* one register */}`
    ///   - `LDM(IA|FD)?` - `{address: _, disp: Disp::Imm(4), write_back: Some(WriteBackMode::ApplyAfter), set: _}`
    ///   - `LDM(DB|EA)?` - `{address: _, disp: Disp::Imm(-4), write_back: Some(WriteBackMode::ApplyBefore), set: _}`
    LoadGpr {
        address: Value<T>,
        disp: Disp,
        write_back: Option<WriteBackMode>,
        set: GprSet,
    },
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum WriteBackMode {
    /// The displacement value is applied after the operation, and the updated
    /// address is written back to the address register.
    PostIndex,
    /// The displacement value is applied before the operation, and the updated
    /// address is written back to the address register.
    PreIndex,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum Value<T> {
    /// A constant value.
    Imm(T),
    /// A label.
    Label(T),
    /// A branch to a variable location specified by a register.
    Gpr(Gpr),
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash)]
pub enum Disp {
    /// A constant displacement value.
    Imm(i32),
    /// A displacement value based on a register. The second value specifies the
    /// left shift count.
    Gpr(Gpr, u8),
}
