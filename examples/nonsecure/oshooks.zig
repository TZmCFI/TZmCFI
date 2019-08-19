// Provides the implementation of FreeRTOS's hook functions.
const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
});

export const SystemCoreClock: u32 = 25000000;

export fn __TCPrivateLeaveInterrupt() void {
    // TODO (This should be defined by TZmCFI Monitor, not here!)
}

export fn SecureContext_LoadContext(contextId: u32) void {
    // TODO
}

export fn SecureContext_SaveContext() void {}

export fn SecureContext_Init() void {}

export fn SecureContext_FreeContext(contextId: i32) void {
    // Can't delete a thread for now :(
}

export fn SecureContext_AllocateContext(contextId: u32, taskPrivileged: u32, pc: usize, lr: usize, exc_return: usize, frame: usize) u32 {
    // TODO
    return 0;
}

export fn SecureInit_DePrioritizeNSExceptions() void {}

/// Stack overflow hook.
export fn vApplicationStackOverflowHook(xTask: os.TaskHandle_t, pcTaskName: *[*]const u8) void {
    // TODO
}
