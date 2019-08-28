// The root source file for the "bench-latency" example application.
const std = @import("std");
const arm_m = @import("arm_m");
const an505 = @import("drivers/an505.zig");
const warn = @import("nonsecure-common/debug.zig").warn;

// zig fmt: off
// The (unprocessed) Non-Secure exception vector table.
export const raw_exception_vectors = @import("nonsecure-common/excvector.zig")
    .getDefaultBaremetal()
    .setExcHandler(an505.irqs.Timer0_IRQn, handleTimer0)
    .setExcHandler(an505.irqs.Timer1_IRQn, handleTimer1);
// zig fmt: on

/// Used for communication between `main` and the interrupt handlers
const CommBlock = struct {
    current_delay: u32 = 0,
    measure_done: u8 = 0,
};

var comm_block = CommBlock{};

fn comm() *volatile CommBlock {
    return @ptrCast(*volatile CommBlock, &comm_block);
}

export fn main() void {
    warn("Starting the interrupt latency benchmark...\r\n");

    warn("\r\n");
    warn("-------------------------------------------------------- \r\n");
    warn("\r\n");

    // Timer1 has a higher priority than Timer0, meaning Timer1 can preempt
    // Timer0's handler.
    arm_m.nvic.setIrqPriority(an505.irqs.Timer0_IRQn - 16, 0x80);
    arm_m.nvic.setIrqPriority(an505.irqs.Timer1_IRQn - 16, 0x10);
    arm_m.nvic.enableIrq(an505.irqs.Timer0_IRQn - 16);
    arm_m.nvic.enableIrq(an505.irqs.Timer1_IRQn - 16);

    an505.timer0.setReloadValue(0x1000000);
    an505.timer1.setReloadValue(0x1000000);

    var i: u32 = 2500;

    while (i < 3500) : (i += 1) {
        comm().current_delay = i;
        comm().measure_done = 0;

        // Timer1 fires late iff i > 3000.
        an505.timer0.setValue(3000 - 1);
        an505.timer1.clearInterruptFlag();

        an505.timer1.setValue(i - 1);
        an505.timer1.clearInterruptFlag();

        an505.timer0.regCtrl().* = 0b1001; // enable, IRQ enable
        an505.timer1.regCtrl().* = 0b1001; // enable, IRQ enable

        while (comm().measure_done < 2) {}
    }

    warn("\r\n");
    warn("-------------------------------------------------------- \r\n");
    warn("\r\n");
    warn("Done!\r\n");

    while (true) {}
}

extern fn handleTimer0() void {
    const timer = an505.timer0;

    // Clear the interrupt flag
    timer.clearInterruptFlag();

    // Stop the timer
    timer.regCtrl().* = 0;

    // Flag the cases where Timer1 preempts Timer0's handler too late
    asm volatile ("cpsid f");
    var k: u32 = 0;
    while (k < 10000) : (k += 1) {
        asm volatile ("");
    }
    asm volatile ("cpsie f");

    comm().measure_done += 1;
}

var last_observed_pattern_hash: u32 = 0;

extern fn handleTimer1() void {
    const timer = an505.timer1;

    // Clear the interrupt flag
    timer.clearInterruptFlag();

    // Stop the timer
    timer.regCtrl().* = 0;

    // Collect information
    const sp = @frameAddress();
    const cycles = timer.getReloadValue() - timer.getValue();

    const pat_hash = sp ^ cycles;

    if (pat_hash != last_observed_pattern_hash) {
        last_observed_pattern_hash = pat_hash;

        // Output in the Python dict literal format
        warn("{{ 'cycles': {}, 'sp': 0x{x:08}, 'delay': {} }},\r\n", cycles, sp, comm().current_delay);
    }

    comm().measure_done += 1;
}

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
