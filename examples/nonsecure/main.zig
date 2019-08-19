const std = @import("std");
const format = @import("std").fmt.format;

const gateways = @import("../common/gateways.zig");

export const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
    @cInclude("timers.h");
});

export const _oshooks = @import("oshooks.zig");

export fn main() void {
    debugOutput("Entering the scheduler.\r\n");

    os.vTaskStartScheduler();

    debugOutput("System halted.\r\n");
    while (true) {}
}

/// Output a formatted text via a Secure gateway.
pub fn debugOutput(comptime fmt: []const u8, args: ...) void {
    format({}, error{}, debugOutputInner, fmt, args) catch unreachable;
}

fn debugOutputInner(ctx: void, data: []const u8) error{}!void {
    _ = gateways.debugOutput(data.len, data.ptr, 0, 0);
}

/// Create an "unhandled exception" handler.
fn unhandled(comptime name: []const u8) extern fn () void {
    const ns = struct {
        extern fn handler() void {
            return unhandledInner(name);
        }
    };
    return ns.handler;
}

fn unhandledInner(name: []const u8) void {
    debugOutput("NS: caught an unhandled exception, system halted: {}\r\n", name);
    while (true) {}
}

/// Not a function, actually, but suppresses type error
extern fn _main_stack_top() void;

/// But this is really a function!
extern fn handleReset() void;

// These are a part of FreeRTOS
extern fn SysTick_Handler() void;
extern fn PendSV_Handler() void;
extern fn SVC_Handler() void;

export const exception_vectors linksection(".isr_vector") = [_]extern fn () void{
    _main_stack_top,
    handleReset,
    unhandled("NMI"), // NMI
    unhandled("HardFault"), // HardFault
    unhandled("MemManage"), // MemManage
    unhandled("BusFault"), // BusFault
    unhandled("UsageFault"), // UsageFault
    unhandled("SecureFault"), // SecureFault
    unhandled("Reserved 1"), // Reserved 1
    unhandled("Reserved 2"), // Reserved 2
    unhandled("Reserved 3"), // Reserved 3
    SVC_Handler, // SVCall
    unhandled("DebugMonitor"), // DebugMonitor
    unhandled("Reserved 4"), // Reserved 4
    PendSV_Handler, // PendSV
    SysTick_Handler, // SysTick
    unhandled("External interrupt 0"), // External interrupt 0
};
