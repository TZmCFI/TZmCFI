const std = @import("std");

const debugOutput = @import("debug.zig").debugOutput;

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
