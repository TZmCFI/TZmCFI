// Provides the implementation of FreeRTOS's hook functions.
const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
});

const tzmcfi = @cImport(@cInclude("TZmCFI/Gateway.h"));

const port = @import("../ports/" ++ @import("build_options").BOARD ++ "/common.zig");

export const SystemCoreClock: u32 = port.system_core_clock;

// `SecureContext_LoadContext`
comptime {
    if (@import("build_options").HAS_TZMCFI_CTX) {
        // Call `TCActivateThread` to switch contexts. This has to be a tail
        // call so that we don't need to spill `lr`. The reason is that we
        // must not have shadow stack entries for the current interrupt
        // handling context at the point of calling `TCActivateThread`,
        // because the destination shadow stack does not have those entries and
        // subsequent shadow assert operations will fail.
        asm (
            \\  .syntax unified
            \\  .thumb
            \\  .cpu cortex-m33
            \\  .type SecureContext_LoadContext function
            \\  .global SecureContext_LoadContext
            \\  SecureContext_LoadContext:
            \\      b TCActivateThread
            \\      // result is ignored, sad
        );
    } else {
        // TZmCFI is disabled, ignore the call
        asm (
            \\  .syntax unified
            \\  .thumb
            \\  .cpu cortex-m33
            \\  .type SecureContext_LoadContext function
            \\  .global SecureContext_LoadContext
            \\  SecureContext_LoadContext:
            \\      bx lr
        );
    }
}

export fn SecureContext_SaveContext() void {}

export fn SecureContext_Init() void {}

export fn SecureContext_FreeContext(contextId: i32) void {
    // Can't delete a thread for now :(
}

export fn SecureContext_AllocateContext(contextId: u32, taskPrivileged: u32, pc: usize, lr: usize, exc_return: usize, frame: usize) u32 {
    if (!@import("build_options").HAS_TZMCFI_CTX) {
        // TZmCFI is disabled, ignore the call
        return 0;
    }

    _ = taskPrivileged;

    const create_info = tzmcfi.TCThreadCreateInfo{
        .flags = .None,
        .stackSize = 4, // unused for now
        .initialPC = pc,
        .initialLR = lr,
        .excReturn = exc_return,
        .exceptionFrame = frame,
    };

    var thread: tzmcfi.TCThread = undefined;

    const result = tzmcfi.TCCreateThread(&create_info, &thread);

    if (result != .TC_RESULT_SUCCESS) {
        @panic("TCCreateThread failed");
    }

    return thread;
}

export fn SecureInit_DePrioritizeNSExceptions() void {}

/// Stack overflow hook.
export fn vApplicationStackOverflowHook(xTask: os.TaskHandle_t, pcTaskName: *[*]const u8) void {
    @panic("stack overflow");
}
