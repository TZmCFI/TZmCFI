const format = @import("std").fmt.format;
const arm_m = @import("arm_m");
const arm_cmse = @import("arm_cmse");
const lpc55s69 = @import("../../drivers/lpc55s69.zig");

pub const VTOR_NS = 0x00200000;

extern var __nsc_start: usize;
extern var __nsc_end: usize;

const Flexcomm = lpc55s69.Flexcomm;
const usart = lpc55s69.flexcomm[0];

const Syscon = lpc55s69.Syscon;
const syscon = lpc55s69.syscon;

const Pmc = lpc55s69.Pmc;
const pmc = lpc55s69.pmc;

const Iocon = lpc55s69.Iocon;
const iocon = lpc55s69.iocon;

const AnaCtrl = lpc55s69.AnaCtrl;
const ana_ctrl = lpc55s69.ana_ctrl;

/// Perform the board-specific initialization.
pub fn init() void {
    // Configure Clock Tree
    // -----------------------------------------------------------------------

    // Power up the crystal oscillator
    pmc.regPdruncdfclr0().* = Pmc.PDRUNCFG0_PDEN_XTAL32M | Pmc.PDRUNCFG0_PDEN_LDOXO32M;

    // Enable CLKIN from the crystal oscillator
    syscon.regClockCtrl().* |= Syscon.CLOCK_CTRL_CLKIN_ENA;

    // Enable the 16MHz crystal oscilaltor
    ana_ctrl.regXo32mCtrl().* |= AnaCtrl.XO32M_CTRL_ENABLE_SYSTEM_CLK_OUT;

    // Wait for it to be stable
    while ((ana_ctrl.regXo32mStatus().* & AnaCtrl.XO32M_STATUS_XO_READY) == 0) {}

    // Power up PLL0
    pmc.regPdruncdfclr0().* = Pmc.PDRUNCFG0_PDEN_PLL0;

    // Select CLKIN as PLL0 input
    syscon.regPll0clksel().* = Syscon.PLL0CLKSEL_CLKIN;

    // Configure PLL0
    syscon.setPll0NDividerRatio(4); // 16MHz / 4 → 4MHz
    syscon.regPll0sscg1().* = 
        Syscon.pll0sscg1MdivExt(75) | // 4MHz * 75 → 300MHz
        Syscon.PLL0SSCG1_MREQ |
        Syscon.PLL0SSCG1_SEL_EXT;
    syscon.setPll0PDividerRatio(3); // 300MHz / 3 → 100MHz
    syscon.regPll0ctrl().* = @bitCast(
        u32,
        Syscon.Pll0ctrl {
            .selr = 0,  // selr = 0
            .seli = 39, // seli = 2 * floor(M / 4) + 3 = 39
            .selp = 19, // selp = floor(M / 4) + 1 = 19
            .bypasspostdiv2 = true, // bypass post divide-by-2
            .clken = true,
        },
    );

    // Wait for PLL0 to lock
    while ((syscon.regPll0stat().* & Syscon.PLL0STAT_LOCK) == 0) {}

    // The required flash memory access time for system clock rates up to
    // 100MHz is 9 system closk
    syscon.regFmccr().* = syscon.regFmccr().*
        & (~Syscon.FMCCR_FLASHTIM_MASK) | Syscon.fmccrFlashtim(8);
    
    // Select PLL0 output as main clock
    syscon.regMainclkselb().* = Syscon.MAINCLKSELB_SEL_PLL0;

    // AHBCLK = main_clk / 1
    syscon.regAhbclkdiv().* = Syscon.ahbclkdivDiv(0);

    // pll0_clk_div = 33.33...MHz
    syscon.regPll0clkdiv().* = 3 - 1;

    // Configure Flexcomm 0 clock to 33.33...MHz / (1 + 75 / 256) → 25.78...MHz (25600/993MHz)
    syscon.regFlexfrgctrl(0).* = Syscon.flexfrgctrlDiv(0xff) | Syscon.flexfrgctrlMult(75);
    syscon.regFcclksel(0).* = Syscon.FCCLKSEL_PLL0DIV;
    
    // Enable Flexcomm 0 clock
    syscon.regAhbclkctrlset1().* = Syscon.ahbclkctrl1Fc(0);

    // Configure USART (Flexcomm 0)
    // -----------------------------------------------------------------------
    
    // Configure the I/O pins
    syscon.regAhbclkctrlset0().* = Syscon.AHBCLKCTRL0_IOCON;
    iocon.regP0(29).* = Iocon.pFunc(1) | Iocon.P_DIGIMODE; // RX: P0_29(1)
    iocon.regP0(30).* = Iocon.pFunc(1); // TX: P0_30(1)
    syscon.regAhbclkctrlclr0().* = Syscon.AHBCLKCTRL0_IOCON;

    // Select USART
    usart.regPselid().* = Flexcomm.PSELID_PERSEL_USART;

    usart.regUsartBrg().* = 14 - 1; // 25.78 MHz / (16 * 14) ≈ 115091 bps
    usart.regFifoCfg().* = Flexcomm.FIFO_CFG_ENABLETX | Flexcomm.FIFO_CFG_ENABLERX;
    usart.regUsartCfg().* = Flexcomm.USART_CFG_ENABLE | Flexcomm.USART_CFG_DATALEN_8BIT;

    // Configure SAU
    // -----------------------------------------------------------------------
    const Region = arm_cmse.SauRegion;
    // Flash memory Non-Secure alias
    arm_cmse.sau.setRegion(0, Region{ .start = 0x00010000, .end = 0x00100000 });
    // SRAM 1–3 Non-Secure alias
    arm_cmse.sau.setRegion(1, Region{ .start = 0x20010000, .end = 0x20040000 });
    // The Non-Secure callable region
    arm_cmse.sau.setRegion(2, Region{
        .start = @ptrToInt(&__nsc_start),
        .end = @ptrToInt(&__nsc_end),
        .nsc = true,
    });
    // Peripherals
    arm_cmse.sau.setRegion(3, Region{ .start = 0x40000000, .end = 0x50000000 });

    // Configure MPCs and IDAU
    // -----------------------------------------------------------------------
    // TODO: The manual says the rules are initialized to `NsNonpriv`. Is this true?
    // Enable Non-Secure access to flash memory (`0x[01]0000000`)
    // for the range `[0x10000, 0xfffff]`.
    // lpc55s69.mpc_flash.setRuleInRange(0x10000, 0x100000, .NsNonpriv);


    // Enable Non-Secure access to RAM1–3 (`0x[01]0200000`)
    // each for the range `[0x0000, 0xffff]`.
    // lpc55s69.mpc_ram1.setRuleInRange(0x0, 0x10000, .NsNonpriv);


    // Allow non-Secure unprivileged access to the timers
    // -----------------------------------------------------------------------
    arm_m.nvic.targetIrqToNonSecure(lpc55s69.irqs.CTimer0_IRQn - 16);
    arm_m.nvic.targetIrqToNonSecure(lpc55s69.irqs.CTimer1_IRQn - 16);

    lpc55s69.ppc_apb_bridge0.setCTimer0Rule(.NsNonpriv);
    lpc55s69.ppc_apb_bridge0.setCTimer1Rule(.NsNonpriv);
}

/// Render the format string `fmt` with `args` and transmit the output.
pub fn print(comptime fmt: []const u8, args: ...) void {
    format({}, error{}, printInner, fmt, args) catch unreachable;
}

fn printInner(ctx: void, data: []const u8) error{}!void {
    usart.writeSlice(data);
}

pub fn printByte(b: u8) void {
    usart.write(b);
}
