const arm_m = @import("arm_m");
const lpc_protchecker = @import("lpc_protchecker.zig");
const flexcomm_driver = @import("flexcomm.zig");

/// Security access rules for flash memory. Each flash sector is 32 kbytes.
/// There are 20 FLASH sectors in total.
pub const mpc_flash = lpc_protchecker.Mpc{
    .base = 0x500ac010,
    .block_size_shift = 15,
    .num_blocks = 20,
};

/// Security access rules for ROM memory. Each ROM sector is 4 kbytes. There
/// are 32 ROM sectors in total.
pub const mpc_rom = lpc_protchecker.Mpc{
    .base = 0x500ac024,
    .block_size_shift = 12,
    .num_blocks = 32,
};

/// Security access rules for RAMX. Each RAMX sub region is 4 kbytes.
pub const mpc_ramx = lpc_protchecker.Mpc{
    .base = 0x500ac040,
    .block_size_shift = 12,
    .num_blocks = 8,
};

/// Security access rules for RAM0. Each RAMX sub region is 4 kbytes.
pub const mpc_ram0 = lpc_protchecker.Mpc{
    .base = 0x500ac060,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM1. Each RAM1 sub region is 4 kbytes.
pub const mpc_ram1 = lpc_protchecker.Mpc{
    .base = 0x500ac080,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM2. Each RAM2 sub region is 4 kbytes.
pub const mpc_ram2 = lpc_protchecker.Mpc{
    .base = 0x500ac0a0,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM3. Each RAM3 sub region is 4 kbytes.
pub const mpc_ram3 = lpc_protchecker.Mpc{
    .base = 0x500ac0c0,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM4. Each RAM4 sub region is 4 kbytes.
pub const mpc_ram4 = lpc_protchecker.Mpc{
    .base = 0x500ac0e0,
    .block_size_shift = 12,
    .num_blocks = 4,
};

pub const PpcApbBridge0 = struct {
    base: usize,

    const Self = @This();

    fn regCtrl1(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x4);
    }

    pub fn setCTimer0Rule(self: Self, rule: lpc_protchecker.ProtCheckerRule) void {
        lpc_protchecker.setRule(self.regCtrl1(), 0, rule);
    }

    pub fn setCTimer1Rule(self: Self, rule: lpc_protchecker.ProtCheckerRule) void {
        lpc_protchecker.setRule(self.regCtrl1(), 4, rule);
    }
};

pub const ppc_apb_bridge0 = PpcApbBridge0{ .base = 0x500AC100 };

pub const Flexcomm = flexcomm_driver.Flexcomm;

/// Flexcomm instances (Secure alias)
pub const flexcomm = [8]Flexcomm{
    Flexcomm{ .base = 0x50086000 },
    Flexcomm{ .base = 0x50087000 },
    Flexcomm{ .base = 0x50088000 },
    Flexcomm{ .base = 0x50089000 },
    Flexcomm{ .base = 0x5008a000 },
    Flexcomm{ .base = 0x50096000 },
    Flexcomm{ .base = 0x50097000 },
    Flexcomm{ .base = 0x50098000 },
};

pub const Syscon = struct {
    base: usize,

    const Self = @This();

    pub fn regAhbclkctrlset0(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x220);
    }
    pub fn regAhbclkctrlclr0(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x240);
    }

    pub const AHBCLKCTRL0_IOCON = bit(13);
    pub const AHBCLKCTRL1_TIMER0 = bit(26);
    pub const AHBCLKCTRL1_TIMER1 = bit(27);

    pub fn regAhbclkctrlset1(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x224);
    }

    pub fn ahbclkctrl1Fc(comptime i: u3) u32 {
        return bit(11 + @as(u5, i));
    }

    pub fn regCtimerclkseln(self: Self, i: usize) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x26c + i * 4);
    }

    pub const CTIMERCLKSEL_SEL_MAIN_CLOCK: u32 = 0;

    pub fn regMainclkselb(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x284);
    }

    pub const MAINCLKSELB_SEL_PLL0: u32 = 1;

    /// This register selects the clock source for the PLL0.
    pub fn regPll0clksel(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x290);
    }

    pub const PLL0CLKSEL_CLKIN: u32 = 1;

    pub fn regFcclksel(self: Self, i: u3) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x2b0 + @as(u32, i) * 4);
    }

    pub const FCCLKSEL_PLL0DIV: u32 = 1;

    pub fn regFlexfrgctrl(self: Self, i: u3) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x320 + @as(u32, i) * 4);
    }

    pub fn flexfrgctrlDiv(ratio: u8) u32 {
        return @as(u32, ratio);
    }

    pub fn flexfrgctrlMult(ratio: u8) u32 {
        return @as(u32, ratio) << 8;
    }

    /// This register determines the divider value for the PLL0 output, if used by the application.
    pub fn regPll0clkdiv(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x3c4);
    }

    pub fn regAhbclkdiv(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x380);
    }

    /// Divide by `t + 1`
    pub fn ahbclkdivDiv(t: u8) u32 {
        return @as(u32, t);
    }

    pub fn regFmccr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x400);
    }

    pub const FMCCR_FLASHTIM_MASK: u32 = fmccrFlashtim(0b11111);
    pub fn fmccrFlashtim(t: u5) u32 {
        return @as(u32, t) << 12;
    }

    /// The PLL0CTRL register provides most of the control over basic
    /// selections of PLL0 modes and operating details.
    pub fn regPll0ctrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x580);
    }

    pub const Pll0ctrl = packed struct {
        selr: u4 = 0,
        seli: u6 = 0,
        selp: u5 = 0,
        bypasspll: bool = false,
        bypasspostdiv2: bool = false,
        limupoff: bool = false,
        bwdirect: bool = false,
        bypassprediv: bool = false,
        bypasspostdiv: bool = false,
        clken: bool = false,
        frmen: bool = false,
        frmclkstable: bool = false,
        skewen: bool = false,
        _pad: u7 = undefined,
    };
    comptime {
        if (@sizeOf(Pll0ctrl) != 4) @compileError("@sizeOf(Pll0ctrl) is not 32-bit long");
    }

    pub fn regPll0stat(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x584);
    }

    pub const PLL0STAT_LOCK = bit(0);

    /// The PLL0NDEC controls operation of the PLL pre-divider.
    pub fn regPll0ndec(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x588);
    }

    pub const PLL0NDEC_NREQ = bit(8);

    pub fn setPll0NDividerRatio(self: Self, ratio: u8) void {
        self.regPll0ndec().* = @as(u32, ratio) | PLL0NDEC_NREQ;
    }

    /// The PLL0PDEC controls operation of the PLL post-divider.
    pub fn regPll0pdec(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x58c);
    }

    pub const PLL0PDEC_NREQ = bit(5);

    pub fn setPll0PDividerRatio(self: Self, ratio: u5) void {
        self.regPll0pdec().* = @as(u32, ratio) | PLL0PDEC_NREQ;
    }

    pub fn regPll0sscg0(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x590);
    }

    pub fn regPll0sscg1(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x594);
    }

    pub fn pll0sscg1MdivExt(x: u16) u32 {
        return @as(u32, x) << 10;
    }

    pub const PLL0SSCG1_MREQ = bit(26);
    pub const PLL0SSCG1_SEL_EXT = bit(28);

    pub fn regCpuctrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x800);
    }

    pub fn regCpboot(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x804);
    }

    pub fn regClockCtrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xa18);
    }

    pub const CLOCK_CTRL_CLKIN_ENA = bit(5);
};

pub const syscon = Syscon{ .base = 0x50000000 };
pub const syscon_ns = Syscon{ .base = 0x40000000 };

pub const Pmc = struct {
    base: usize,

    const Self = @This();

    /// The power configuration clear register 0 controls the power to various
    /// analog blocks.
    pub fn regPdruncdfclr0(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xc8);
    }

    pub const PDRUNCFG0_PDEN_XTAL32M = bit(8);
    pub const PDRUNCFG0_PDEN_PLL0 = bit(9);
    pub const PDRUNCFG0_PDEN_LDOXO32M = bit(20);
};

pub const pmc = Pmc{ .base = 0x50020000 };

/// Analog control
pub const AnaCtrl = struct {
    base: usize,

    const Self = @This();

    pub fn regXo32mCtrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x20);
    }

    pub const XO32M_CTRL_ENABLE_SYSTEM_CLK_OUT = bit(24);

    pub fn regXo32mStatus(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x24);
    }

    pub const XO32M_STATUS_XO_READY = bit(0);
};

pub const ana_ctrl = AnaCtrl{ .base = 0x50013000 };

/// I/O Pin Configuration
pub const Iocon = struct {
    base: usize,

    const Self = @This();

    pub fn regP0(self: Self, i: u32) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + i * 4);
    }
    pub fn regP1(self: Self, i: u32) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x080 + i * 4);
    }

    pub fn pFunc(f: u32) u32 {
        return f;
    }
    pub const P_DIGIMODE = bit(8);
};

pub const iocon = Iocon{ .base = 0x50001000 };

/// Standard counter/time
pub const CTimer = struct {
    base: usize,

    const Self = @This();

    /// Interrupt Register. The IR can be written to clear interrupts. The IR
    /// can be read to identify which of eight possible interrupt sources are
    /// pending.
    pub fn regIr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x00);
    }

    /// Interrupt flag for match channel 0.
    pub const IR_MR0INT = bit(0);

    /// Interrupt flag for match channel 1.
    pub const IR_MR1INT = bit(1);

    /// Interrupt flag for match channel 2.
    pub const IR_MR2INT = bit(2);

    /// Interrupt flag for match channel 3.
    pub const IR_MR3INT = bit(3);

    /// Interrupt flag for capture channel 0 event.
    pub const IR_CR0INT = bit(4);

    /// Interrupt flag for capture channel 1 event.
    pub const IR_CR1INT = bit(5);

    /// Interrupt flag for capture channel 2 event.
    pub const IR_CR2INT = bit(6);

    /// Interrupt flag for capture channel 3 event.
    pub const IR_CR3INT = bit(7);

    /// Timer Control Register. The TCR is used to control the Timer Counter
    /// functions. The Timer Counter can be disabled or reset through the TCR.
    pub fn regTcr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x04);
    }

    /// Counter enable.
    pub const TCR_CEN = bit(0);

    /// Counter reset.
    pub const TCR_CRST = bit(1);

    /// Timer Counter. The 32 bit TC is incremented every PR+1 cycles of the
    /// APB bus clock. The TC is controlled through the TCR.
    pub fn regTc(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x08);
    }

    /// Prescale Register. When the Prescale Counter (PC) is equal to this
    /// value, the next clock increments the TC and clears the PC.
    pub fn regPr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x0c);
    }

    /// Prescale Counter. The 32 bit PC is a counter which is incremented to
    /// the value stored in PR. When the value in PR is reached, the TC is
    /// incremented and the PC is cleared. The PC is observable and controllable
    /// through the bus interface.
    pub fn regPc(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x10);
    }

    /// The MCR is used to control whether an interrupt is generated, whether the
    /// TC is reset when a Match occurs, and whether the match register is reloaded
    /// from its shadow register when the TC is reset.
    pub fn regMcr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x14);
    }

    /// Interrupt on MR0: an interrupt is generated when MR0 matches the value
    /// in the TC.
    pub const MCR_MR0I = bit(0);

    /// Reset on MR0: the TC will be reset if MR0 matches it.
    pub const MCR_MR0R = bit(1);

    /// Stop on MR0: the TC and PC will be stopped and TCR[0] will be set to 0
    /// if MR0 matches the TC.
    pub const MCR_MR0S = bit(2);

    /// Match Register 0–3. MR0 can be enabled through the MCR to reset the TC,
    /// stop both the TC and PC, and/or generate an interrupt every time MR0
    /// matches the TC.
    pub fn regMr(self: Self, n: usize) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x18 + n * 4);
    }
};

pub const ctimers = [_]CTimer{
    CTimer{ .base = 0x50008000 },
    CTimer{ .base = 0x50009000 },
    CTimer{ .base = 0x50028000 },
    CTimer{ .base = 0x50029000 },
    CTimer{ .base = 0x5002a000 },
};
pub const ctimers_ns = [_]CTimer{
    CTimer{ .base = 0x40008000 },
    CTimer{ .base = 0x40009000 },
    CTimer{ .base = 0x40028000 },
    CTimer{ .base = 0x40029000 },
    CTimer{ .base = 0x4002a000 },
};

/// The number of hardware interrupt lines.
pub const num_irqs = 60;

pub const irqs = struct {
    pub const CTimer0_IRQn = arm_m.irqs.interruptIRQn(10);
    pub const CTimer1_IRQn = arm_m.irqs.interruptIRQn(11);
    pub const CTimer2_IRQn = arm_m.irqs.interruptIRQn(36);
    pub const CTimer3_IRQn = arm_m.irqs.interruptIRQn(13);
    pub const CTimer4_IRQn = arm_m.irqs.interruptIRQn(37);
    pub const CTimern_IRQn = [_]usize{
        CTimer0_IRQn, CTimer1_IRQn, CTimer2_IRQn, CTimer3_IRQn, CTimer4_IRQn,
    };

    /// Get the descriptive name of an exception number. Returns `null` if
    /// the exception number is not known by this module.
    pub fn getName(comptime i: usize) ?[]const u8 {
        switch (i) {
            CTimer0_IRQn => return "CTimer0",
            CTimer1_IRQn => return "CTimer1",
            else => return arm_m.irqs.getName(i),
        }
    }
};

fn bit(comptime n: u32) u32 {
    return 1 << n;
}
