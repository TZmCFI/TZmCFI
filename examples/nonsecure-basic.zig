// The root source file for the "basic" example application.
const std = @import("std");
const arm_m = @import("arm_m");
const warn = @import("nonsecure-common/debug.zig").warn;
const port = @import("ports/" ++ @import("build_options").BOARD ++ "/nonsecure.zig");

// The (unprocessed) Non-Secure exception vector table.
// zig fmt: off
export const raw_exception_vectors linksection(".text.raw_isr_vector") =
    @import("nonsecure-common/excvector.zig")
        .getDefaultBaremetal()
        .setTcExcHandler(arm_m.irqs.SysTick_IRQn, handleSysTick);
// zig fmt: on
export fn main() void {
    port.init();

    warn("yay\r\n", .{});

    // Configure SysTick
    // -----------------------------------------------------------------------
    arm_m.sys_tick.regRvr().* = 1000 * 100; // fire every 100 milliseconds
    arm_m.sys_tick.regCsr().* = arm_m.SysTick.CSR_ENABLE |
        arm_m.SysTick.CSR_TICKINT;

    while (true) {}
}

var counter: u8 = 0;

fn handleSysTick() callconv(.C) void {
    counter +%= 1;
    warn("\r{}", .{"|\\-/"[counter % 4 ..][0..1]});
}

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
