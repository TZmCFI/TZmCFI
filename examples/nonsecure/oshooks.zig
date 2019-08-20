// Provides the implementation of FreeRTOS's hook functions.
const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
});

const tzmcfi = @cImport(@cInclude("TZmCFI/Gateway.h"));

export const SystemCoreClock: u32 = 25000000;

export fn SecureContext_LoadContext(contextId: u32) void {
    const result = tzmcfi.TCActivateThread(contextId);
    if (result != tzmcfi.TC_RESULT_SUCCESS) {
        @panic("TCActivateThread failed");
    }
}

export fn SecureContext_SaveContext() void {}

export fn SecureContext_Init() void {}

export fn SecureContext_FreeContext(contextId: i32) void {
    // Can't delete a thread for now :(
}

export fn SecureContext_AllocateContext(contextId: u32, taskPrivileged: u32, pc: usize, lr: usize, exc_return: usize, frame: usize) u32 {
    _ = taskPrivileged;

    const create_info = tzmcfi.TCThreadCreateInfo{
        .flags = tzmcfi.TCThreadCreateFlagsNone,
        .stackSize = 4, // unused for now
        .initialPC = pc,
        .initialLR = lr,
        .excReturn = exc_return,
        .exceptionFrame = frame,
    };

    var thread: tzmcfi.TCThread = undefined;

    const result = tzmcfi.TCCreateThread(&create_info, &thread);

    if (result != tzmcfi.TC_RESULT_SUCCESS) {
        @panic("TCCreateThread failed");
    }

    return thread;
}

export fn SecureInit_DePrioritizeNSExceptions() void {}

/// Stack overflow hook.
export fn vApplicationStackOverflowHook(xTask: os.TaskHandle_t, pcTaskName: *[*]const u8) void {
    @panic("stack overflow");
}
