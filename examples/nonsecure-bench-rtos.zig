// The root source file for the “bench-rtos” example application.
const std = @import("std");
const an505 = @import("drivers/an505.zig");
const warn = @import("nonsecure-common/debug.zig").warn;

// FreeRTOS-related thingy
const os = @cImport({
    @cInclude("FreeRTOS.h");
    @cInclude("task.h");
    @cInclude("timers.h");
});
export const _oshooks = @import("nonsecure-common/oshooks.zig");

// The (unprocessed) Non-Secure exception vector table.
export const raw_exception_vectors linksection(".text.raw_isr_vector") = @import("nonsecure-common/excvector.zig").getDefaultFreertos();

// The entry point. The reset handler transfers the control to this function
// after initializing data sections.
export fn main() void {
    seqmon.mark(0);

    // Get the measurement overhead
    measure.calculateOverhead();
    warn("Overhead: {} cycles (this value is subtracted from all subsequent measurements)\r\n", measure.overhead);

    _ = os.xTaskCreateRestricted(&task1_params, 0);

    os.vTaskStartScheduler();
    unreachable;
}

var task1_stack = [1]u32{0} ** 128;

const regions_with_peripheral_access = [3]os.MemoryRegion_t{
    // TODO: It seems that this is actually not needed for measurements to work.
    //       Investigate why
    os.MemoryRegion_t{
        .pvBaseAddress = @intToPtr(*c_void, 0x40000000),
        .ulLengthInBytes = 0x10000000,
        .ulParameters = 0,
    },
    os.MemoryRegion_t{
        .pvBaseAddress = null,
        .ulLengthInBytes = 0,
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
    .pcName = c"task1",
    .usStackDepth = task1_stack.len,
    .pvParameters = null,
    .uxPriority = 2,
    .puxStackBuffer = &task1_stack,
    .xRegions = regions_with_peripheral_access,
    .pxTaskBuffer = null,
};

var task2_stack = [1]u32{0} ** 128;

const task2_params = os.TaskParameters_t{
    .pvTaskCode = task2Main,
    .pcName = c"task2",
    .usStackDepth = task2_stack.len,
    .pvParameters = null,
    .uxPriority = 4,
    .puxStackBuffer = &task2_stack,
    .xRegions = regions_with_peripheral_access,
    .pxTaskBuffer = null,
};

var task3_stack = [1]u32{0} ** 32;

const task3_params = os.TaskParameters_t{
    .pvTaskCode = badTaskMain,
    .pcName = c"task3",
    .usStackDepth = task3_stack.len,
    .pvParameters = null,
    .uxPriority = 0, // must be the lowest
    .puxStackBuffer = &task3_stack,
    .xRegions = regions_with_peripheral_access,
    .pxTaskBuffer = null,
};

extern fn task1Main(_arg: ?*c_void) void {
    seqmon.mark(1);

    // `xTaskCreateRestricted` without dispatch
    var task3_handle: os.TaskHandle_t = undefined;
    measure.start();
    _ = os.xTaskCreateRestricted(&task3_params, &task3_handle);
    measure.end();
    warn("Unpriv xTaskCreateRestricted without dispatch: {} cycles\r\n", measure.getNumCycles());

    // `vTaskDelete`
    measure.start();
    _ = os.vTaskDelete(task3_handle);
    measure.end();
    warn("Unpriv vTaskDelete without dispatch: {} cycles\r\n", measure.getNumCycles());

    seqmon.mark(2);

    // `xTaskCreateRestricted` without dispatch
    var task2_handle: os.TaskHandle_t = undefined;
    measure.start();
    _ = os.xTaskCreateRestricted(&task2_params, &task2_handle);

    // task2 returns to here by calling `vTaskDelete`
    measure.end();
    seqmon.mark(4);
    warn("Unpriv vTaskDelete with dispatch: {} cycles\r\n", measure.getNumCycles());

    warn("Done!\r\n");
    while (true) {}
}

extern fn task2Main(_arg: ?*c_void) void {
    measure.end();
    warn("Unpriv xTaskCreateRestricted with dispatch: {} cycles\r\n", measure.getNumCycles());

    seqmon.mark(3);

    // `vTaskDelete`
    measure.start();
    _ = os.vTaskDelete(null);
    unreachable;
}

extern fn badTaskMain(_arg: ?*c_void) void {
    @panic("this task is not supposed to run");
}

/// Measurement routines
const measure = struct {
    const TIMER_RESET_VALUE: u32 = 0x80000000;
    var overhead: i32 = 0;

    fn __measureStart() void {
        an505.timer0.setValue(TIMER_RESET_VALUE);
        an505.timer0.regCtrl().* = 0b0001; // enable
    }

    fn __measureEnd() void {
        an505.timer0.regCtrl().* = 0b0000;
    }

    inline fn start() void {
        // Defeat inlining for consistent timing
        @noInlineCall(__measureStart);
    }
    inline fn end() void {
        @noInlineCall(__measureEnd);
    }

    fn calculateOverhead() void {
        start();
        end();
        overhead = getNumCycles();
    }

    fn getNumCycles() i32 {
        return @intCast(i32, TIMER_RESET_VALUE - an505.timer0.getValue()) - overhead;
    }
};

/// Execution sequence monitoring
const seqmon = struct {
    var next_ordinal: u32 = 0;

    /// Declare a checkpoint. `ordinal` is a sequence number that starts at
    /// `0`. Aborts the execution on a sequence violation.
    fn mark(ordinal: u32) void {
        if (ordinal != next_ordinal) {
            warn("execution sequence violation: expected {}, got {}\r\n", ordinal, next_ordinal);
            @panic("execution sequence violation");
        }

        warn("[{}]\r\n", ordinal);
        next_ordinal += 1;
    }
};

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
