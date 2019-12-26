// Timer abstraction for a Non-Secure benchmark program
const an505 = @import("../../drivers/an505.zig");
const CmsdkTimer = @import("../../drivers/cmsdk_timer.zig").CmsdkTimer;

pub const irqs = struct {
    pub const Timer0_IRQn = an505.irqs.Timer0_IRQn;
    pub const Timer1_IRQn = an505.irqs.Timer1_IRQn;
};

const CmsdkTimerWrap = struct {
    inner: CmsdkTimer,

    const Self = @This();

    pub fn getValue(self: Self) u32 {
        return self.inner.getValue();
    }

    pub fn setValue(self: Self, x: u32) void {
        self.inner.setValue(x);
    }

    pub fn getReloadValue(self: Self) u32 {
        return self.inner.getReloadValue();
    }

    pub fn setReloadValue(self: Self, x: u32) void {
        self.inner.setReloadValue(x);
    }

    pub fn clearInterruptFlag(self: Self) void {
        self.inner.clearInterruptFlag();
    }

    pub fn start(self: Self) void {
        self.inner.regCtrl().* = 0b0001; // enable
    }

    pub fn startWithInterruptEnabled(self: Self) void {
        self.inner.regCtrl().* = 0b1001; // enable, IRQ enable
    }

    pub fn stop(self: Self) void {
        self.inner.regCtrl().* = 0b0000;
    }
};

pub const timer0 = CmsdkTimerWrap{ .inner = an505.timer0 };
pub const timer1 = CmsdkTimerWrap{ .inner = an505.timer1 };
