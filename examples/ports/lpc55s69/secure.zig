const format = @import("std").fmt.format;
const arm_m = @import("arm_m");
const arm_cmse = @import("arm_cmse");
const lpc55s69 = @import("../../drivers/lpc55s69.zig");

pub const VTOR_NS = 0x00200000;

extern var __nsc_start: usize;
extern var __nsc_end: usize;

const Flexcomm = lpc55s69.Flexcomm;
const usart = lpc55s69.flexcomm[0];

/// Perform the board-specific initialization.
pub fn init() void {
    // Configure USART
    // -----------------------------------------------------------------------
    // TODO: configure clock

    usart.regPselid().* = Flexcomm.PSELID_PERSEL_USART;

    usart.regUsartBrg().* = 14 - 1; // 25.8 MHz / (16 * 14) ~ 115207 bps
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
