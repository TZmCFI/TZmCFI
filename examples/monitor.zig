// The root source file for TZmCFI Monitor library, which resides
// in a Secure region.
// ----------------------------------------------------------------------------
const builtin = @import("builtin");
const arm_m = @import("arm_m");
const tzmcfi_monitor = @import("tzmcfi-monitor");
const port = @import("ports/" ++ @import("build_options").BOARD ++ "/secure.zig");
// ----------------------------------------------------------------------------
const exports = @import("monitor/exports.zig");
// ----------------------------------------------------------------------------

// Pass build options to `tzmcfi`, which picks them up via `@import("root")`
// See `src/monitor/options.zig`.
pub const TC_ENABLE_PROFILER = @import("build_options").ENABLE_PROFILE;
pub const TC_ABORTING_SHADOWSTACK = @import("build_options").ABORTING_SHADOWSTACK;
pub const TC_LOG_LEVEL = @import("build_options").LOG_LEVEL;

var cur_warn_handler: ?exports.WarnHandler = null;

// Implements `exports.TCXInitializeMonitor`
export fn TCXInitializeMonitor(warn_handler: exports.WarnHandler) void {
    cur_warn_handler = warn_handler;
    tzmcfi_monitor.setWarnHandler(monitorWarnHandler);
    tzmcfi_monitor.TCInitialize(port.VTOR_NS);
}

fn monitorWarnHandler(_: void, msg: []const u8) error{}!void {
    if (cur_warn_handler) |warn_handler| {
        warn_handler(@ptrCast([*]const u8, &msg[0]), msg.len);
    }
}

/// The global panic handler. (The compiler looks for `pub fn panic` in the root
/// source file. See `zig/std/special/panic.zig`.)
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    tzmcfi_monitor.log(.Critical, "panic: {}\r\n", .{msg});
    @breakpoint();
    unreachable;
}

// `tzmcfi` hooks
// ----------------------------------------------------------------------------

pub fn tcSetShadowStackGuard(stack_start: usize, stack_end: usize) void {
    const mpu = arm_m.mpu;
    const Mpu = arm_m.Mpu;

    mpu.regRnr().* = 0;

    // `stack_start - 32 .. stack_start`, overlapping the region 2
    mpu.regRbar().* = (stack_start - 32) | Mpu.RBAR_AP_RW_ANY;
    mpu.regRlar().* = (stack_start - 32) | Mpu.RLAR_EN;

    // `stack_end .. stack_end + 32`, overlapping the region 2
    mpu.regRbarA(1).* = stack_end | Mpu.RBAR_AP_RW_ANY;
    mpu.regRlarA(1).* = stack_end | Mpu.RLAR_EN;
}

pub fn tcResetShadowStackGuard() void {
    @panic("tcResetShadowStackGuard: not implemented");
}