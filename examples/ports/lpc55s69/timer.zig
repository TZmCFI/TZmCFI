// Timer abstraction for a Non-Secure benchmark program
const lpc55s69 = @import("../../drivers/lpc55s69.zig");

pub const irqs = struct {
    pub const Timer0_IRQn = lpc55s69.irqs.CTimer0_IRQn;
    pub const Timer1_IRQn = lpc55s69.irqs.CTimer1_IRQn;
};

const CTimer = lpc55s69.CTimer;

const TimerWrap = struct {
    ctimer: CTimer,

    const Self = @This();

    pub fn getValue(self: Self) u32 {
        return self.ctimer.regMr(0).* - self.ctimer.regTc().*;
    }

    pub fn setValue(self: Self, x: u32) void {
        self.ctimer.regTc().* = self.ctimer.regMr(0).* - x;
    }

    pub fn getReloadValue(self: Self) u32 {
        return self.ctimer.regMr(0).*;
    }

    pub fn setReloadValue(self: Self, x: u32) void {
        self.ctimer.regMr(0).* = x;
    }

    pub fn clearInterruptFlag(self: Self) void {
        self.ctimer.regIr().* = CTimer.IR_MR0INT;
    }

    pub fn start(self: Self) void {
        self.ctimer.regMcr().* = CTimer.MCR_MR0R;
        self.ctimer.regTcr().* = CTimer.TCR_CEN;
    }

    pub fn startWithInterruptEnabled(self: Self) void {
        self.ctimer.regMcr().* = CTimer.MCR_MR0R | CTimer.MCR_MR0I;
        self.ctimer.regTcr().* = CTimer.TCR_CEN;
    }

    pub fn stop(self: Self) void {
        self.ctimer.regTcr().* = 0;
    }
};

pub const timer0 = TimerWrap{ .ctimer = lpc55s69.ctimers_ns[0] };
pub const timer1 = TimerWrap{ .ctimer = lpc55s69.ctimers_ns[1] };
