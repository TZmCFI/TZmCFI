use super::*;
use std::fmt;

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

impl fmt::Display for Gpr {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{}",
            [
                "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12",
                "sp", "lr", "pc",
            ][self.0 as usize]
        )
    }
}

impl fmt::Display for GprSet {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        for (i, gpr) in self.iter().enumerate() {
            if i > 0 {
                write!(f, ", ")?;
            }
            write!(f, "{}", gpr)?;
        }
        Ok(())
    }
}

impl fmt::Display for Cond {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{}",
            [
                "eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc", "hi", "ls", "ge", "lt", "gt", "le",
                "",
            ][*self as usize]
        )
    }
}

impl<T: fmt::Display> fmt::Display for Value<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            &Value::Imm(ref x) => write!(f, "{}", x),
            &Value::Label(ref x) => write!(f, "{}", x),
            &Value::Gpr(x) => write!(f, "{}", x),
        }
    }
}

impl fmt::Display for Disp {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            &Disp::Imm(x) => write!(f, "#{}", x),
            &Disp::Gpr(x, 0) => write!(f, "{}", x),
            &Disp::Gpr(x, shift) => write!(f, "{}, lsl #{}", x, shift),
        }
    }
}

impl<'a> fmt::Display for ArmDirective<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            &ArmDirective::Inst(ref inst) => match inst.kind {
                InstKind::Branch {
                    target,
                    link,
                    nonsecure,
                } => {
                    write!(f, "b")?;
                    if link {
                        write!(f, "l")?;
                    }
                    if let Value::Gpr(_) = target {
                        write!(f, "x")?;
                    }
                    if nonsecure {
                        write!(f, "ns")?;
                    }
                    write!(f, "{} {}", inst.cond, target)
                }
                InstKind::LoadGpr {
                    address,
                    disp,
                    write_back,
                    set,
                } => match (address, disp, write_back, set.unique()) {
                    (Value::Label(label), disp, write_back, Some(to)) => {
                        assert_eq!(disp, Disp::Imm(0));
                        assert_eq!(write_back, None);
                        write!(f, "ldr{} {}, {}", inst.cond, to, label)
                    }
                    (address, Disp::Imm(0), None, Some(to)) => {
                        write!(f, "ldr{} {}, [{}]", inst.cond, to, address)
                    }
                    (address, disp, None, Some(to)) => {
                        write!(f, "ldr{} {}, [{}, {}]", inst.cond, to, address, disp)
                    }
                    (address, Disp::Imm(x), Some(WriteBackMode::PreIndex), Some(to)) => {
                        write!(f, "ldr{} {}, [{}, #{}]!", inst.cond, to, address, x)
                    }
                    (address, Disp::Imm(x), Some(WriteBackMode::PostIndex), Some(to)) => {
                        write!(f, "ldr{} {}, [{}], #{}", inst.cond, to, address, x)
                    }
                    (address, Disp::Imm(-4), Some(WriteBackMode::PreIndex), None) => {
                        write!(f, "ldmdb{} {}!, {{{}}}", inst.cond, address, set)
                    }
                    (address, Disp::Imm(4), Some(WriteBackMode::PostIndex), None) => {
                        write!(f, "ldmia{} {}!, {{{}}}", inst.cond, address, set)
                    }
                    _ => {
                        panic!("Unsupported 'LDR' variant: {:?}", inst);
                    }
                },
            },
            &ArmDirective::Misc(kind, cond, rest) => write!(f, "{}{} {}", kind, cond, rest),
        }
    }
}
