// The root source file for the "profile-ses" example application.
//
// This application does the same thing as "bench-latency", except that instead
// of a final interrupt latency, the execution time of each instruction along
// the execution path is in question.
const std = @import("std");
const arm_m = @import("arm_m");
const warn = @import("nonsecure-common/debug.zig").warn;
const port = @import("ports/" ++ @import("build_options").BOARD ++ "/nonsecure.zig");
const port_timer = @import("ports/" ++ @import("build_options").BOARD ++ "/timer.zig");
const nonsecure_init = @import("nonsecure-common/init.zig");
const gateways = @import("common/gateways.zig");

// zig fmt: off
// The (unprocessed) Non-Secure exception vector table.
export const raw_exception_vectors linksection(".text.raw_isr_vector") =
    @import("nonsecure-common/excvector.zig")
        .getDefaultBaremetal()
        .setTcExcHandler(port_timer.irqs.Timer0_IRQn, handleTimer0)
        .setTcExcHandler(port_timer.irqs.Timer1_IRQn, handleTimer1);
// zig fmt: on
/// Used for communication between `main` and the interrupt handlers
const CommBlock = struct {
    measure_done: u8 = 0,
};

var comm_block = CommBlock{};

fn comm() *volatile CommBlock {
    return @ptrCast(*volatile CommBlock, &comm_block);
}

export fn main() void {
    port.init();
    nonsecure_init.disableNestedExceptionIfDisallowed();

    warn("Starting the SES profiling application...\r\n", .{});

    warn("\r\n", .{});
    warn("-------------------------------------------------------- \r\n", .{});
    warn("%output-start\r\n", .{});
    warn("[\r\n", .{});

    // Timer1 has a higher priority than Timer0, meaning Timer1 can preempt
    // Timer0's handler.
    arm_m.nvic.setIrqPriority(port_timer.irqs.Timer0_IRQn - 16, 0x80);
    arm_m.nvic.setIrqPriority(port_timer.irqs.Timer1_IRQn - 16, 0x10);
    arm_m.nvic.enableIrq(port_timer.irqs.Timer0_IRQn - 16);
    arm_m.nvic.enableIrq(port_timer.irqs.Timer1_IRQn - 16);

    port_timer.timer0.setReloadValue(0x1000000);
    port_timer.timer1.setReloadValue(0x1000000);

    // The measurement points wrt timer skew
    const delay_values = [_]u32{ 2980, 3000, 3040, 3100, 3120, 3140 };

    for (delay_values) |delay| {
        // PC sampling time
        var i: u32 = 2800;
        while (true) : (i += 1) {
            comm().measure_done = 0;

            // Timer1 fires late iff delay > 3000.
            port_timer.timer0.setValue(3000 - 1);
            port_timer.timer0.clearInterruptFlag();

            port_timer.timer1.setValue(delay - 1);
            port_timer.timer1.clearInterruptFlag();

            // Sample the program counter after `i` cycles
            _ = gateways.scheduleSamplePc(@as(usize, i), 0, 0, 0);

            port_timer.timer0.startWithInterruptEnabled();
            port_timer.timer1.startWithInterruptEnabled();

            while (comm().measure_done < 2) {}

            // Get the sampled PC
            const sampled_pc = gateways.getSampledPc(0, 0, 0, 0);
            if (sampled_pc == 0) {
                // PC hasn't been sampled yet; `i` is too large. Break the loop.
                // But first we must wait until the current PC sampling is
                // complete not to mess up the next iteration.
                while (gateways.getSampledPc(0, 0, 0, 0) == 0) {}

                // Output a record at least once
                if (i > 2800) {
                    break;
                }
            }

            // Output in the JSON5 format
            warn("  {{ \"delay\": {}, \"cycles\": {}, \"pc\": {}, \"pc_hex\": \"0x{x}\" }},\r\n", .{ delay, i, sampled_pc, sampled_pc });
        }
    }

    warn("]\r\n", .{});
    warn("%output-end\r\n", .{});
    warn("-------------------------------------------------------- \r\n", .{});
    warn("\r\n", .{});
    warn("Done!\r\n", .{});

    while (true) {}
}

fn handleTimer0() callconv(.C) void {
    const timer = port_timer.timer0;

    // Clear the interrupt flag
    timer.clearInterruptFlag();

    // Stop the timer
    timer.stop();

    // Flag the cases where Timer1 preempts Timer0's handler too late
    asm volatile ("cpsid f");
    var k: u32 = 0;
    while (k < 1000) : (k += 1) {
        asm volatile ("");
    }
    comm().measure_done += 1;
    asm volatile ("cpsie f");
}

var last_observed_pattern_hash: u32 = 0;

fn handleTimer1() callconv(.C) void {
    const timer = port_timer.timer1;

    // Clear the interrupt flag
    timer.clearInterruptFlag();

    // Stop the timer
    timer.stop();

    asm volatile ("cpsid f");
    comm().measure_done += 1;
    asm volatile ("cpsie f");
}

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
