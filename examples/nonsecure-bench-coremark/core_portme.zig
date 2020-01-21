const c = @cImport({
    @cInclude("coremark.h");
    @cInclude("core_portme.h");
});
const warn = @import("../nonsecure-common/debug.zig").warn;

const timer = @import("../ports/" ++ @import("build_options").BOARD ++ "/timer.zig").timer0;
const port_ns = @import("../ports/" ++ @import("build_options").BOARD ++ "/nonsecure.zig");
const port = @import("../ports/" ++ @import("build_options").BOARD ++ "/common.zig");

const tzmcfi = @cImport(@cInclude("TZmCFI/Gateway.h"));

const TIMER_RESET_VALUE: u32 = 0x80000000;

/// This function will be called right before starting the timed portion of the benchmark.
///
/// Implementation may be capturing a system timer (as implemented in the example code)
/// or zeroing some system parameters - e.g. setting the cpu clocks cycles to 0.
export fn start_time() void {
    tzmcfi.TCDebugStartProfiler();
    timer.setValue(TIMER_RESET_VALUE);
    timer.start();
}

/// This function will be called right after ending the timed portion of the benchmark.
///
/// Implementation may be capturing a system timer (as implemented in the example code)
/// or other system parameters - e.g. reading the current value of cpu cycles counter.
export fn stop_time() void {
    timer.stop();
    tzmcfi.TCDebugStopProfiler();
    tzmcfi.TCDebugDumpProfile();
}

/// Return an abstract "ticks" number that signifies time on the system.
///
/// Actual value returned may be cpu cycles, milliseconds or any other value,
/// as long as it can be converted to seconds by <time_in_secs>.
/// This methodology is taken to accomodate any hardware or simulated platform.
/// The sample implementation returns millisecs by default,
/// and the resolution is controlled by <TIMER_RES_DIVIDER>
export fn get_time() c.CORE_TICKS {
    return TIMER_RESET_VALUE - timer.getValue();
}

/// Convert the value returned by get_time to seconds.
///
/// The <secs_ret> type is used to accomodate systems with no support for floating point.
/// Default implementation implemented by the EE_TICKS_PER_SEC macro above.
export fn time_in_secs(ticks: c.CORE_TICKS) c.secs_ret {
    return @intToFloat(f64, ticks) / port.system_core_clock;
}

export var default_num_contexts: c.ee_u32 = 1;

comptime {
    if (@sizeOf(c.ee_ptr_int) != @sizeOf([*c]c.ee_u8)) {
        @compileError("ERROR! Please define ee_ptr_int to a type that holds a pointer!");
    }
    if (@sizeOf(c.ee_u32) != 4) {
        @compileError("ERROR! Please define ee_u32 to a 32b unsigned type!");
    }
}

/// Target specific initialization code
export fn portable_init(p: *c.core_portable, _argc: *c_int, _argv: ?[*]([*]u8)) void {
    port_ns.init();

    p.portable_id = 1;
    warn("* portable_init\r\n", .{});
}

/// Target specific final code
export fn portable_fini(p: *c.core_portable) void {
    p.portable_id = 0;
    warn("* portable_fini - system halted\r\n", .{});

    while (true) {}
}

export fn uart_send_char(ch: u8) void {
    if (ch == '\n') {
        warn("\r\n", .{});
    } else {
        warn("{}", .{&[_]u8{ch}});
    }
}
