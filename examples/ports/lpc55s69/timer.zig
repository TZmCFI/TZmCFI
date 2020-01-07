// Timer abstraction for a Non-Secure benchmark program
const lpc55s69 = @import("../../drivers/lpc55s69.zig");

pub const irqs = struct {
    pub const Timer0_IRQn = lpc55s69.irqs.CTimer0_IRQn;
    pub const Timer1_IRQn = lpc55s69.irqs.CTimer1_IRQn;
};

const TimerWrap = struct {
    const Self = @This();

    pub fn getValue(self: Self) u32 {
        @panic("not implemented");
    }

    pub fn setValue(self: Self, x: u32) void {
        @panic("not implemented");
    }

    pub fn getReloadValue(self: Self) u32 {
        @panic("not implemented");
    }

    pub fn setReloadValue(self: Self, x: u32) void {
        @panic("not implemented");
    }

    pub fn clearInterruptFlag(self: Self) void {
        @panic("not implemented");
    }

    pub fn start(self: Self) void {
        @panic("not implemented");
    }

    pub fn startWithInterruptEnabled(self: Self) void {
        @panic("not implemented");
    }

    pub fn stop(self: Self) void {
        @panic("not implemented");
    }
};

pub const timer0 = TimerWrap{};
pub const timer1 = TimerWrap{};
