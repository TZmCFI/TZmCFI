// Special LR values for Secure/Non-Secure call handling and exception handling

// Function Return Payload (from ARMv8-M Architecture Reference Manual) LR value on entry from Secure BLXNS
pub const FNC_RETURN: usize = 0xFEFFFFFF; // bit [0] ignored when processing a branch

/// These EXC_RETURN mask values are used to evaluate the LR on exception entry.
pub const EXC_RETURN = struct {
    pub const PREFIX: usize = 0xFF000000; // bits [31:24] set to indicate an EXC_RETURN value
    pub const S: usize = 0x00000040; // bit [6] stack used to push registers: 0=Non-secure 1=Secure
    pub const DCRS: usize = 0x00000020; // bit [5] stacking rules for called registers: 0=skipped 1=saved
    pub const FTYPE: usize = 0x00000010; // bit [4] allocate stack for floating-point context: 0=done 1=skipped
    pub const MODE: usize = 0x00000008; // bit [3] processor mode for return: 0=Handler mode 1=Thread mode
    pub const SPSEL: usize = 0x00000004; // bit [2] stack pointer used to restore context: 0=MSP 1=PSP
    pub const ES: usize = 0x00000001; // bit [0] security state exception was taken to: 0=Non-secure 1=Secure
};

/// Cortex-M SysTick timer.
///
/// The availability of SysTick(s) depends on the hardware configuration.
/// A PE implementing Armv8-M may include up to two instances of SysTick, each
/// for Secure and Non-Secure. Secure code can access the Non-Secure instance
/// via `sys_tick_ns` (`0xe002e010`).
pub const SysTick = struct {
    base: usize,

    const Self = @This();

    /// Construct a `SysTick` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    /// SysTick Control and Status Register
    pub fn regCsr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base);
    }

    pub const CSR_COUNTFLAG: u32 = 1 << 16;
    pub const CSR_CLKSOURCE: u32 = 1 << 2;
    pub const CSR_TICKINT: u32 = 1 << 1;
    pub const CSR_ENABLE: u32 = 1 << 0;

    /// SysTick Reload Value Register
    pub fn regRvr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x4);
    }

    /// SysTick Current Value Register
    pub fn regCvr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x8);
    }

    /// SysTick Calibration Value Register
    pub fn regCalib(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xc);
    }
};

/// Represents the SysTick instance corresponding to the current security mode.
pub const sys_tick = SysTick.withBase(0xe000e010);

/// Represents the Non-Secure SysTick instance. This register is only accessible
/// by Secure mode (Armv8-M or later).
pub const sys_tick_ns = SysTick.withBase(0xe002e010);

/// Nested Vectored Interrupt Controller.
pub const Nvic = struct {
    base: usize,

    const Self = @This();

    /// Construct an `Nvic` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    // Register Accessors
    // -----------------------------------------------------------------------

    /// Interrupt Set Enable Register.
    pub fn regIser(self: Self) *volatile [16]u32 {
        return @intToPtr(*volatile [16]u32, self.base);
    }

    /// Interrupt Clear Enable Register.
    pub fn regIcer(self: Self) *volatile [16]u32 {
        return @intToPtr(*volatile [16]u32, self.base + 0x80);
    }

    /// Interrupt Set Pending Register.
    pub fn regIspr(self: Self) *volatile [16]u32 {
        return @intToPtr(*volatile [16]u32, self.base + 0x100);
    }

    /// Interrupt Clear Pending Register.
    pub fn regIcpr(self: Self) *volatile [16]u32 {
        return @intToPtr(*volatile [16]u32, self.base + 0x180);
    }

    /// Interrupt Active Bit Register.
    pub fn regIabr(self: Self) *volatile [16]u32 {
        return @intToPtr(*volatile [16]u32, self.base + 0x200);
    }

    /// Interrupt Target Non-Secure Register (Armv8-M or later). RAZ/WI from
    /// Non-Secure.
    pub fn regItns(self: Self) *volatile [16]u32 {
        return @intToPtr(*volatile [16]u32, self.base + 0x280);
    }

    /// Interrupt Priority Register.
    pub fn regIpri(self: Self) *volatile [512]u8 {
        return @intToPtr(*volatile [512]u8, self.base + 0x300);
    }

    // Helper functions
    // -----------------------------------------------------------------------
    // Note: Interrupt numbers are different from exception numbers.
    // An exception number `Interrupt_IRQn(i)` corresponds to an interrupt
    // number `i`.

    /// Enable the interrupt number `irq`.
    pub fn enableIrq(self: Self, irq: usize) void {
        self.regIser()[irq >> 5] = @as(u32, 1) << @truncate(u5, irq);
    }

    /// Disable the interrupt number `irq`.
    pub fn disableIrq(self: Self, irq: usize) void {
        self.regIcer()[irq >> 5] = @as(u32, 1) << @truncate(u5, irq);
    }

    /// Set the priority of the interrupt number `irq` to `pri`.
    pub fn setIrqPriority(self: Self, irq: usize, pri: u8) void {
        self.regIpri()[irq] = pri;
    }

    /// Set the target state of the interrupt number `irq` to Non-Secure (Armv8-M or later).
    pub fn targetIrqToNonSecure(self: Self, irq: usize) void {
        self.regItns()[irq >> 5] |= @as(u32, 1) << @truncate(u5, irq);
    }
};

/// Represents the Nested Vectored Interrupt Controller instance corresponding
/// to the current security mode.
pub const nvic = Nvic.withBase(0xe000e100);

/// Represents the Non-Secure Nested Vectored Interrupt Controller instance.
/// This register is only accessible by Secure mode (Armv8-M or later).
pub const nvic_ns = Nvic.withBase(0xe002e100);

/// System Control Block.
pub const Scb = struct {
    base: usize,

    const Self = @This();

    /// Construct an `Nvic` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    // Register Accessors
    // -----------------------------------------------------------------------

    /// System Handler Control and State Register
    pub fn regShcsr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x124);
    }

    pub const SHCSR_MEMFAULTACT: u32 = 1 << 0;
    pub const SHCSR_BUSFAULTACT: u32 = 1 << 1;
    pub const SHCSR_HARDFAULTACT: u32 = 1 << 2;
    pub const SHCSR_USGFAULTACT: u32 = 1 << 3;
    pub const SHCSR_SECUREFAULTACT: u32 = 1 << 4;
    pub const SHCSR_NMIACT: u32 = 1 << 5;
    pub const SHCSR_SVCCALLACT: u32 = 1 << 7;
    pub const SHCSR_MONITORACT: u32 = 1 << 8;
    pub const SHCSR_PENDSVACT: u32 = 1 << 10;
    pub const SHCSR_SYSTICKACT: u32 = 1 << 11;
    pub const SHCSR_USGFAULTPENDED: u32 = 1 << 12;
    pub const SHCSR_MEMFAULTPENDED: u32 = 1 << 13;
    pub const SHCSR_BUSFAULTPENDED: u32 = 1 << 14;
    pub const SHCSR_SYSCALLPENDED: u32 = 1 << 15;
    pub const SHCSR_MEMFAULTENA: u32 = 1 << 16;
    pub const SHCSR_BUSFAULTENA: u32 = 1 << 17;
    pub const SHCSR_USGFAULTENA: u32 = 1 << 18;
    pub const SHCSR_SECUREFAULTENA: u32 = 1 << 19;
    pub const SHCSR_SECUREFAULTPENDED: u32 = 1 << 20;
    pub const SHCSR_HARDFAULTPENDED: u32 = 1 << 21;

    /// Application Interrupt and Reset Control Register
    pub fn regAircr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x10c);
    }

    pub const AIRCR_VECTCLRACTIVE: u32 = 1 << 1;
    pub const AIRCR_SYSRESETREQ: u32 = 1 << 2;
    pub const AIRCR_SYSRESETREQS: u32 = 1 << 3;
    pub const AIRCR_DIT: u32 = 1 << 4;
    pub const AIRCR_IESB: u32 = 1 << 5;
    pub const AIRCR_PRIGROUP_SHIFT: u5 = 8;
    pub const AIRCR_PRIGROUP_MASK: u32 = 0b111 << AIRCR_PRIGROUP_SHIFT;
    pub const AIRCR_BFHFNMINS: u32 = 1 << 13;
    pub const AIRCR_PRIS: u32 = 1 << 14;
    pub const AIRCR_ENDIANNESS: u32 = 1 << 15;
    pub const AIRCR_VECTKEY_SHIFT: u5 = 16;
    pub const AIRCR_VECTKEY_MASK: u32 = 0xffff << AIRCR_VECTKEY_SHIFT;
    pub const AIRCR_VECTKEY_MAGIC: u32 = 0x05fa;

    pub fn setPriorityGrouping(self: Self, subpriority_msb: u3) void {
        self.regAircr().* = self.regAircr().* & ~(AIRCR_PRIGROUP_MASK | AIRCR_VECTKEY_MASK)
            | (@as(u32, subpriority_msb) << AIRCR_PRIGROUP_SHIFT)
            | (AIRCR_VECTKEY_MAGIC << AIRCR_VECTKEY_SHIFT);
    }

    /// Vector Table Offset Register
    pub fn regVtor(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x108);
    }
};

/// Represents the System Control Block instance corresponding to the current
/// security mode.
pub const scb = Scb.withBase(0xe000ec00);

/// Represents the System Control Block instance for Non-Secure mode.
/// This register is only accessible by Secure mode (Armv8-M or later).
pub const scb_ns = Scb.withBase(0xe002ec00);

/// Exception numbers defined by Arm-M.
pub const irqs = struct {
    pub const Reset_IRQn: usize = 1;
    pub const Nmi_IRQn: usize = 2;
    pub const SecureHardFault_IRQn: usize = 3;
    pub const MemManageFault_IRQn: usize = 4;
    pub const BusFault_IRQn: usize = 5;
    pub const UsageFault_IRQn: usize = 6;
    pub const SecureFault_IRQn: usize = 7;
    pub const SvCall_IRQn: usize = 11;
    pub const DebugMonitor_IRQn: usize = 12;
    pub const PendSv_IRQn: usize = 14;
    pub const SysTick_IRQn: usize = 15;
    pub const InterruptBase_IRQn: usize = 16;

    pub fn interruptIRQn(i: usize) usize {
        return @This().InterruptBase_IRQn + i;
    }

    /// Get the descriptive name of an exception number. Returns `null` for a value
    /// outside the range `[Reset_IRQn, SysTick_IRQn]`.
    pub fn getName(i: usize) ?[]const u8 {
        switch (i) {
            Reset_IRQn => return "Reset",
            Nmi_IRQn => return "Nmi",
            SecureHardFault_IRQn => return "SecureHardFault",
            MemManageFault_IRQn => return "MemManageFault",
            BusFault_IRQn => return "BusFault",
            UsageFault_IRQn => return "UsageFault",
            SecureFault_IRQn => return "SecureFault",
            SvCall_IRQn => return "SvCall",
            DebugMonitor_IRQn => return "DebugMonitor",
            PendSv_IRQn => return "PendSv",
            SysTick_IRQn => return "SysTick",
            else => return null,
        }
    }
};

pub inline fn getIpsr() usize {
    return asm ("mrs %[out], ipsr"
        : [out] "=r" (-> usize)
    );
}

pub inline fn isHandlerMode() bool {
    return getIpsr() != 0;
}

/// Read the current main stack pointer.
pub inline fn getMsp() usize {
    return asm ("mrs %[out], msp"
        : [out] "=r" (-> usize)
    );
}

/// Read the current process stack pointer.
pub inline fn getPsp() usize {
    return asm ("mrs %[out], psp"
        : [out] "=r" (-> usize)
    );
}

/// Read the current main stack pointer limit.
pub inline fn getMspLimit() usize {
    return asm ("mrs %[out], msplim"
        : [out] "=r" (-> usize)
    );
}

/// Read the current process stack pointer limit.
pub inline fn getPspLimit() usize {
    return asm ("mrs %[out], psplim"
        : [out] "=r" (-> usize)
    );
}

/// Write the current main stack pointer.
pub inline fn setMsp(value: usize) void {
    return asm volatile ("msr msp, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Write the current process stack pointer.
pub inline fn setPsp(value: usize) void {
    return asm volatile ("msr psp, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Write the current main stack pointer limit.
pub inline fn setMspLimit(value: usize) void {
    return asm volatile ("msr msplim, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Write the current process stack pointer limit.
pub inline fn setPspLimit(value: usize) void {
    return asm volatile ("msr psplim, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Read the current non-Secure main stack pointer.
pub inline fn getMspNs() usize {
    return asm ("mrs %[out], msp_ns"
        : [out] "=r" (-> usize)
    );
}

/// Read the current non-Secure process stack pointer.
pub inline fn getPspNs() usize {
    return asm ("mrs %[out], psp_ns"
        : [out] "=r" (-> usize)
    );
}

/// Read the current non-Secure main stack pointer limit.
pub inline fn getMspLimitNs() usize {
    return asm ("mrs %[out], msplim_ns"
        : [out] "=r" (-> usize)
    );
}

/// Read the current non-Secure process stack pointer limit.
pub inline fn getPspLimitNs() usize {
    return asm ("mrs %[out], psplim_ns"
        : [out] "=r" (-> usize)
    );
}

/// Write the current non-Secure main stack pointer.
pub inline fn setMspNs(value: usize) void {
    return asm volatile ("msr msp_ns, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Write the current non-Secure process stack pointer.
pub inline fn setPspNs(value: usize) void {
    return asm volatile ("msr psp_ns, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Write the current non-Secure main stack pointer limit.
pub inline fn setMspLimitNs(value: usize) void {
    return asm volatile ("msr msplim_ns, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Write the current non-Secure process stack pointer limit.
pub inline fn setPspLimitNs(value: usize) void {
    return asm volatile ("msr psplim_ns, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Read the control register.
pub inline fn getControl() usize {
    return asm ("mrs %[out], control"
        : [out] "=r" (-> usize)
    );
}

/// Write the control register.
pub inline fn setControl(value: usize) void {
    return asm volatile ("msr control, %[value]"
        :
        : [value] "r" (value)
    );
}

/// Read the non-Secure control register.
pub inline fn getControlNs() usize {
    return asm ("mrs %[out], control_ns"
        : [out] "=r" (-> usize)
    );
}

/// Write the non-Secure control register.
pub inline fn setControlNs(value: usize) void {
    return asm volatile ("msr control_ns, %[value]"
        :
        : [value] "r" (value)
    );
}

pub const control = struct {
    /// Secure Floating-point active.
    pub const SPFA: usize = 1 << 3;

    /// Floating-point context active.
    pub const FPCA: usize = 1 << 2;

    /// Stack-pointer select.
    pub const SPSEL: usize = 1 << 1;

    /// Not privileged.
    pub const nPRIV: usize = 1 << 0;

    pub const set = setControl;
    pub const get = getControl;
};

/// Set `FAULTMASK`, disabling all interrupts.
pub inline fn setFaultmask() void {
    asm volatile ("cpsid f");
}

/// Clear `FAULTMASK`, re-enabling all interrupts.
pub inline fn clearFaultmask() void {
    asm volatile ("cpsie f");
}

/// Memory Protection Unit.
pub const Mpu = struct {
    base: usize,

    const Self = @This();

    /// Construct an `Mpu` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    // Register Accessors
    // -----------------------------------------------------------------------

    /// MPU Type Register
    pub fn regType(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x00);
    }

    /// MPU Control Register
    pub fn regCtrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x04);
    }

    /// Privileged default enable.
    pub const CTRL_PRIVDEFENA: u32 = 1 << 2;

    /// HardFault, NMI enable.
    pub const CTRL_HFNMIENA: u32 = 1 << 1;

    /// Enable.
    pub const CTRL_ENABLE: u32 = 1 << 0;

    /// MPU Region Number Register
    pub fn regRnr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x08);
    }

    /// MPU Region Base Address Register
    pub fn regRbar(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x0c);
    }

    /// MPU Region Limit Address Register
    pub fn regRlar(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x10);
    }

    /// MPU Region Base Address Register Alias `n` (where 1 ≤ `n` ≤ 3)
    pub fn regRbarA(self: Self, n: usize) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x14 + (n - 1) * 8);
    }

    /// MPU Region Limit Address Register Alias `n` (where 1 ≤ `n` ≤ 3)
    pub fn regRlarA(self: Self, n: usize) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x18 + (n - 1) * 8);
    }

    /// MPU Memory Attribute Indirection Register `n` (where 0 ≤ `n` ≤ 1)
    pub fn regMair(self: Self, n: usize) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x30 + n * 4);
    }

    pub const RBAR_BASE_MASK: u32 = 0xffffffe0;
    pub const RBAR_SH_NON_SHAREABLE: u32 = 0b00 << 3;
    pub const RBAR_SH_OUTER_SHAREABLE: u32 = 0b10 << 3;
    pub const RBAR_SH_INNER_SHAREABLE: u32 = 0b11 << 3;
    pub const RBAR_AP_RW_PRIV: u32 = 0b00 << 1;
    pub const RBAR_AP_RW_ANY: u32 = 0b01 << 1;
    pub const RBAR_AP_RO_PRIV: u32 = 0b10 << 1;
    pub const RBAR_AP_RO_ANY: u32 = 0b11 << 1;
    pub const RBAR_XN: u32 = 1;

    pub const RLAR_LIMIT_MASK: u32 = 0xffffffe0;
    pub const RLAR_PXN: u32 = 1 << 4;
    pub const RLAR_ATTR_MASK: u32 = 0b111 << 1;
    pub const RLAR_EN: u32 = 1;
};

/// Represents theMemory Protection Unit instance corresponding to the current
/// security mode.
pub const mpu = Mpu.withBase(0xe000ed90);
