const std = @import("std");

const arm_cmse = @import("arm_cmse");
const arm_m = @import("arm_m");
const an505 = @import("../drivers/an505.zig");

const tzmcfi_monitor = @import("tzmcfi-monitor");

extern var __nsc_start: usize;
extern var __nsc_end: usize;

export fn main() void {
    // Enable SecureFault, UsageFault, BusFault, and MemManage for ease of
    // debugging. (Without this, they all escalate to HardFault)
    arm_m.scb.regShcsr().* =
        arm_m.Scb.SHCSR_MEMFAULTENA |
        arm_m.Scb.SHCSR_BUSFAULTENA |
        arm_m.Scb.SHCSR_USGFAULTENA |
        arm_m.Scb.SHCSR_SECUREFAULTENA;

    // Enable Non-Secure BusFault, HardFault, and NMI.
    // Prioritize Secure exceptions.
    arm_m.scb.regAircr().* =
        (arm_m.scb.regAircr().* & ~arm_m.Scb.AIRCR_VECTKEY_MASK) |
        arm_m.Scb.AIRCR_BFHFNMINS | arm_m.Scb.AIRCR_PRIS |
        arm_m.Scb.AIRCR_VECTKEY_MAGIC;

    // :( <https://github.com/ziglang/zig/issues/504>
    an505.uart0_s.configure(25e6, 115200);
    an505.uart0_s.print("(Hit ^A X to quit QEMU)\r\n");
    an505.uart0_s.print("The Secure code is running!\r\n");

    // Intialize secure stacks
    // -----------------------------------------------------------------------
    // On reset, MSP is used for both of Thread and Handler modes. We want to
    // set a new stack pointer only for Handler mode by updating MSP, but MSP
    // is currently in use. So, we first copy MSP To PSP and then switch to
    // PSP.
    asm volatile (
        \\ mrs r0, msp
        \\ msr psp, r0
        \\ mrs r0, control
        \\ orr r0, #2       // SPSEL = 1 (Use PSP in Thread mode)
        \\ msr control, r0
        :
        :
        : "r0"
    );

    // Now we can safely update MSP.
    arm_m.setMsp(@ptrToInt(_handler_stack_top));

    // Set stack limits.
    arm_m.setMspLimit(@ptrToInt(_handler_stack_limit));
    arm_m.setPspLimit(@ptrToInt(_main_stack_limit));

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

    // Enable SAU
    // -----------------------------------------------------------------------
    arm_cmse.sau.regCtrl().* |= arm_cmse.Sau.CTRL_ENABLE;

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

    // Initialize TZmCFI Monitor
    // -----------------------------------------------------------------------
    tzmcfi_monitor.setWarnHandler(tcWarnHandler);
    tzmcfi_monitor.TCInitialize(0x00200000);

    // Boot the Non-Secure code
    // -----------------------------------------------------------------------
    // Configure the Non-Secure exception vector table
    arm_m.scb_ns.regVtor().* = 0x00200000;

    an505.uart0_s.print("Booting the Non-Secure code...\r\n");

    // Call Non-Secure code's entry point
    const ns_entry = @intToPtr(*volatile fn () void, 0x00200004).*;
    _ = arm_cmse.nonSecureCall(ns_entry, 0, 0, 0, 0);

    @panic("Non-Secure reset handler returned unexpectedly");
}

fn tcWarnHandler(ctx: void, data: []const u8) error{}!void {
    for (data) |byte| {
        an505.uart0_s.write(byte);
    }
}

/// The Non-Secure-callable function that outputs zero or more bytes to the
/// debug output.
extern fn nsDebugOutput(count: usize, ptr: usize, r2: usize, r32: usize) usize {
    const bytes = arm_cmse.checkSlice(u8, ptr, count, arm_cmse.CheckOptions{}) catch |err| {
        an505.uart0_s.print("warning: pointer security check failed: {}\r\n", err);
        an505.uart0_s.print("         count = {}, ptr = 0x{x}\r\n", count, ptr);
        return 0;
    };

    // Even if the permission check has succeeded, it's still unsafe to treat
    // Non-Secure pointers as normal pointers (this is why `bytes` is
    // `[]volatile u8`), so we can't use `writeSlice` here.
    for (bytes) |byte| {
        an505.uart0_s.write(byte);
    }

    return 0;
}

comptime {
    arm_cmse.exportNonSecureCallable("debugOutput", nsDebugOutput);
}

// Build the exception vector table
// zig fmt: off
const VecTable = @import("../common/vectable.zig").VecTable;
export const exception_vectors linksection(".isr_vector") =
    VecTable(an505.num_irqs, an505.irqs.getName)
        .new()
        .setInitStackPtr(_main_stack_top)
        .setExcHandler(arm_m.irqs.Reset_IRQn, handleReset);
// zig fmt: on
extern fn _main_stack_top() void;
extern fn _handler_stack_top() void;
extern fn _main_stack_limit() void;
extern fn _handler_stack_limit() void;
extern fn handleReset() void;
