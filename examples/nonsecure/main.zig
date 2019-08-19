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

    debugOutput("Creating an idle task.\r\n");
    _ = os.xTaskCreateRestricted(&idle_task_params, 0);

    debugOutput("Creating a timer.\r\n");
    const timer = os.xTimerCreate(c"saluton", 100, os.pdTRUE, null, timerHandler);
    _ = xTimerStart(timer, 0);

    debugOutput("Entering the scheduler.\r\n");
    os.vTaskStartScheduler();

    debugOutput("System halted.\r\n");
    while (true) {}
}

fn xTimerStart(timer: os.TimerHandle_t, ticks: os.TickType_t) os.BaseType_t {
    return os.xTimerGenericCommand(timer, os.tmrCOMMAND_START, os.xTaskGetTickCount(), null, ticks);
}

var i: u32 = 0;
extern fn timerHandler(_arg: ?*os.tmrTimerControl) void {
    i +%= 1;
    debugOutput("The timer has fired for {} time(s)!\r\n", i);
}

var idle_task_stack = [1]u32{0} ** 64;

const idle_task_params = os.TaskParameters_t{
    .pvTaskCode = idleTaskMain,
    .pcName = c"saluton",
    .usStackDepth = idle_task_stack.len,
    .pvParameters = null,
    .uxPriority = 0,
    .puxStackBuffer = &idle_task_stack,
    .xRegions = [1]os.MemoryRegion_t{os.MemoryRegion_t{
        .pvBaseAddress = null,
        .ulLengthInBytes = 0,
        .ulParameters = 0,
    }} ** 3,
    .pxTaskBuffer = null,
};

extern fn idleTaskMain(_arg: ?*c_void) void {
    debugOutput("The idle task is running.\r\n");
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
