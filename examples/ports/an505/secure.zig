const format = @import("std").fmt.format;
const OutStream = @import("std").io.OutStream;
const arm_m = @import("arm_m");
const arm_cmse = @import("arm_cmse");
const an505 = @import("../../drivers/an505.zig");

pub const VTOR_NS = 0x00200000;

extern var __nsc_start: usize;
extern var __nsc_end: usize;

/// Perform the board-specific initialization.
pub fn init() void {
    // :( <https://github.com/ziglang/zig/issues/504>
    an505.uart0_s.configure(25e6, 115200);

    // Configure SAU
    // -----------------------------------------------------------------------
    const Region = arm_cmse.SauRegion;
    // AN505 ZBT SRAM (SSRAM1) Non-Secure alias
    arm_cmse.sau.setRegion(0, Region{ .start = 0x00200000, .end = 0x00400000 });
    // AN505 ZBT SRAM (SSRAM3) Non-Secure alias
    arm_cmse.sau.setRegion(1, Region{ .start = 0x28200000, .end = 0x28400000 });
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
    // Enable Non-Secure access to SSRAM1 (`0x[01]0200000`)
    // for the range `[0x200000, 0x3fffff]`.
    an505.ssram1_mpc.setEnableBusError(true);
    an505.ssram1_mpc.assignRangeToNonSecure(0x200000, 0x400000);

    // Enable Non-Secure access to SSRAM3 (`0x[23]8200000`)
    // for the range `[0, 0x1fffff]`.
    // - It seems that the range SSRAM3's MPC encompasses actually starts at
    //   `0x[23]8000000`.
    // - We actually use only the first `0x4000` bytes. However the hardware
    //   block size is larger than that and the rounding behavior of
    //   `tz_mpc.zig` is unspecified, so specify the larger range.
    an505.ssram3_mpc.setEnableBusError(true);
    an505.ssram3_mpc.assignRangeToNonSecure(0x200000, 0x400000);

    // Configure IDAU to enable Non-Secure Callable regions
    // for the code memory `[0x10000000, 0x1dffffff]`
    an505.spcb.regNsccfg().* |= an505.Spcb.NSCCFG_CODENSC;

    // Allow non-Secure unprivileged access to the timers
    // -----------------------------------------------------------------------
    arm_m.nvic.targetIrqToNonSecure(an505.irqs.Timer0_IRQn - 16);
    arm_m.nvic.targetIrqToNonSecure(an505.irqs.Timer1_IRQn - 16);
    arm_m.nvic.targetIrqToNonSecure(an505.irqs.DualTimer_IRQn - 16);

    an505.spcb.setPpcAccess(an505.ppc.timer0_, .NonSecure, true);
    an505.spcb.setPpcAccess(an505.ppc.timer1_, .NonSecure, true);
    an505.spcb.setPpcAccess(an505.ppc.dual_timer_, .NonSecure, true);

    an505.nspcb.setPpcAccess(an505.ppc.timer0_, true);
    an505.nspcb.setPpcAccess(an505.ppc.timer1_, true);
    an505.nspcb.setPpcAccess(an505.ppc.dual_timer_, true);
}

/// Render the format string `fmt` with `args` and transmit the output.
pub fn print(comptime fmt: []const u8, args: var) void {
    const out_stream = OutStream(void, error{}, printInner){ .context = {} };
    format(out_stream, fmt, args) catch unreachable;
}

fn printInner(ctx: void, data: []const u8) error{}!usize {
    an505.uart0_s.writeSlice(data);
    return data.len;
}

pub fn printByte(b: u8) void {
    an505.uart0_s.write(b);
}
