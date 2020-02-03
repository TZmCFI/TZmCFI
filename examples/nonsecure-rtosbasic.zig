// The root source file for the "rtosbasic" example application.
const std = @import("std");
const warn = @import("nonsecure-common/debug.zig").warn;
const port = @import("ports/" ++ @import("build_options").BOARD ++ "/nonsecure.zig");

// FreeRTOS-related thingy
const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
    @cInclude("timers.h");
});
comptime {
    _ = @import("nonsecure-common/oshooks.zig");
}

// The (unprocessed) Non-Secure exception vector table.
export const raw_exception_vectors linksection(".text.raw_isr_vector") = @import("nonsecure-common/excvector.zig").getDefaultFreertos();

// The entry point. The reset handler transfers the control to this function
// after initializing data sections.
export fn main() void {
    port.init();

    warn("Creating an idle task.\r\n", .{});
    _ = os.xTaskCreateRestricted(&idle_task_params, 0);

    warn("Creating a timer.\r\n", .{});
    const timer = os.xTimerCreate("saluton", 100, os.pdTRUE, null, getTrampoline_timerHandler());
    _ = xTimerStart(timer, 0);

    warn("Entering the scheduler.\r\n", .{});
    os.vTaskStartScheduler();
    unreachable;
}

fn xTimerStart(timer: os.TimerHandle_t, ticks: os.TickType_t) os.BaseType_t {
    return os.xTimerGenericCommand(timer, os.tmrCOMMAND_START, os.xTaskGetTickCount(), null, ticks);
}

extern fn getTrampoline_timerHandler() extern fn (_arg: ?*os.tmrTimerControl) void;

var i: u32 = 0;
export fn timerHandler(_arg: ?*os.tmrTimerControl) void {
    i +%= 1;
    warn("The timer has fired for {} time(s)!\r\n", .{i});
}

var idle_task_stack = [1]u32{0} ** 128;

const idle_task_params = os.TaskParameters_t{
    .pvTaskCode = idleTaskMain,
    .pcName = "saluton",
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

fn idleTaskMain(_arg: ?*c_void) callconv(.C) void {
    warn("The idle task is running.\r\n", .{});
    while (true) {}
}

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
