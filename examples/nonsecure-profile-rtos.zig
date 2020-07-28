// The root source file for the “profile-rtos” example application.
//
// This application captures the execution path and execution time while
// calling FreeRTOS's API functions.
const std = @import("std");
const arm_m = @import("arm_m");
const timer = @import("ports/" ++ @import("build_options").BOARD ++ "/timer.zig").timer0;
const tzmcfi = @cImport(@cInclude("TZmCFI/Gateway.h"));
const warn = @import("nonsecure-common/debug.zig").warn;
const port = @import("ports/" ++ @import("build_options").BOARD ++ "/nonsecure.zig");
const nonsecure_init = @import("nonsecure-common/init.zig");
const gateways = @import("common/gateways.zig");

// FreeRTOS-related thingy
const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
    @cInclude("timers.h");
    @cInclude("semphr.h");
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
    nonsecure_init.disableNestedExceptionIfDisallowed();

    warn("%output-start\r\n", .{});
    warn("[\r\n", .{});

    seqmon.mark(0);
    
    global_mutex1.* = xSemaphoreCreateBinary();
    global_mutex2.* = xSemaphoreCreateBinary();
    _ = xSemaphoreGive(global_mutex1.*);

    _ = os.xTaskCreateRestricted(&task1_params, 0);

    os.vTaskStartScheduler();
    unreachable;
}

var task1_stack align(32) = [1]u32{0} ** 192;

const regions_with_peripheral_access = [3]os.MemoryRegion_t{
    // TODO: It seems that this is actually not needed for measurements to work.
    //       Investigate why
    os.MemoryRegion_t{
        .pvBaseAddress = @intToPtr(*c_void, 0x40000000),
        .ulLengthInBytes = 0x10000000,
        .ulParameters = 0,
    },
    os.MemoryRegion_t{
        .pvBaseAddress = @ptrCast(*c_void, &unpriv_state),
        .ulLengthInBytes = @sizeOf(@TypeOf(unpriv_state)) + 32,
        .ulParameters = 0,
    },
    os.MemoryRegion_t{
        .pvBaseAddress = null,
        .ulLengthInBytes = 0,
        .ulParameters = 0,
    },
};

const task1_params = os.TaskParameters_t{
    .pvTaskCode = task1Main,
    .pcName = "task1",
    .usStackDepth = task1_stack.len,
    .pvParameters = null,
    .uxPriority = 2 | os.portPRIVILEGE_BIT,
    .puxStackBuffer = &task1_stack,
    .xRegions = regions_with_peripheral_access,
    .pxTaskBuffer = null,
};

var task2_stack align(32) = [1]u32{0} ** 192;

const task2b_params = os.TaskParameters_t{
    .pvTaskCode = task2bMain,
    .pcName = "task2b",
    .usStackDepth = task2_stack.len,
    .pvParameters = null,
    .uxPriority = 4, // > task1
    .puxStackBuffer = &task2_stack,
    .xRegions = regions_with_peripheral_access,
    .pxTaskBuffer = null,
};

const global_mutex1 = &unpriv_state.global_mutex1;
const global_mutex2 = &unpriv_state.global_mutex2;

fn task1Main(_arg: ?*c_void) callconv(.C) void {
    // Disable SysTick
    arm_m.sys_tick.regCsr().* = 0;

    // Make us unprivileged
    os.vResetPrivilege();

    // Create a high-priority task `task2b` to be dispatched on `xSemaphoreGive`
    var task2_handle: os.TaskHandle_t = undefined;
    _ = os.xTaskCreateRestricted(&task2b_params, &task2_handle);

    // -----------------------------------------------------------------------
    var sample_time: u32 = 1;

    while (sample_time < 10000) : (sample_time += 1) {
        // Sample the program counter after `i` cycles
        _ = gateways.scheduleSamplePc(@as(usize, sample_time), 0, 0, 0);
    
        unpriv_state.next_ordinal = 2;

        seqmon.mark(2);

        // `xSemaphoreTake` without dispatch
        _ = xSemaphoreTake(global_mutex1.*, portMAX_DELAY);

        // `xSemaphoreGive` with dispatch
        _ = xSemaphoreGive(global_mutex2.*);

        seqmon.mark(5);

        // Get the sampled PC
        const sampled_pc = gateways.getSampledPc(0, 0, 0, 0);
        if (sampled_pc == 0) {
            // PC hasn't been sampled yet; `i` is too large. Break the loop.
            break;
        }

        // Output in the JSON5 format
        warn("  {{ \"cycles\": {}, \"pc\": {}, \"pc_hex\": \"0x{x}\" }},\r\n", .{ sample_time, sampled_pc, sampled_pc });
    }

    warn("]\r\n", .{});
    warn("%output-end\r\n", .{});
    warn("Done!\r\n", .{});
    while (true) {}
}


fn task2bMain(_arg: ?*c_void) callconv(.C) void {
    seqmon.mark(1);

    // This will block and gives the control back to task1
    _ = xSemaphoreTake(global_mutex2.*, portMAX_DELAY);

    while (true) {
        seqmon.mark(3);
        _ = xSemaphoreGive(global_mutex1.*);

        seqmon.mark(4);

        // This will block and gives the control back to task1
        _ = xSemaphoreTake(global_mutex2.*, portMAX_DELAY);
    }

    unreachable;
}

/// unprivilileged state data
var unpriv_state align(32) = struct {
    next_ordinal: u32 = 0,
    global_mutex1: os.SemaphoreHandle_t = undefined,
    global_mutex2: os.SemaphoreHandle_t = undefined,
}{};

/// Execution sequence monitoring
const seqmon = struct {
    const next_ordinal = &unpriv_state.next_ordinal;

    /// Declare a checkpoint. `ordinal` is a sequence number that starts at
    /// `0`. Aborts the execution on a sequence violation.
    fn mark(ordinal: u32) void {
        if (ordinal != next_ordinal.*) {
            warn("execution sequence violation: expected {}, got {}\r\n", .{ ordinal, next_ordinal.* });
            @panic("execution sequence violation");
        }

        next_ordinal.* += 1;
    }
};

// FreeRTOS wrapper
const queueQUEUE_TYPE_MUTEX = 1;
const queueQUEUE_TYPE_BINARY_SEMAPHORE = 3;
const semGIVE_BLOCK_TIME = 0;
const semSEMAPHORE_QUEUE_ITEM_LENGTH = 0;
const portMAX_DELAY = 0xffffffff;
fn xSemaphoreCreateBinary() os.SemaphoreHandle_t {
    return os.xQueueGenericCreate(1, semSEMAPHORE_QUEUE_ITEM_LENGTH, queueQUEUE_TYPE_BINARY_SEMAPHORE);
}
const xSemaphoreTake = os.xQueueSemaphoreTake;
fn xSemaphoreGive(semaphore: os.SemaphoreHandle_t) @TypeOf(os.xQueueGenericSend).ReturnType {
    return os.xQueueGenericSend(semaphore, null, semGIVE_BLOCK_TIME, os.queueSEND_TO_BACK);
}

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
