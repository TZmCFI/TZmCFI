/// The device driver for the CMSDK timer
///
/// It is documented in the ARM CoreLink SSE-200 System IP for Embedded TRM.
pub const CmsdkTimer = struct {
    base: usize,

    const Self = @This();

    /// Construct a `CmsdkTimer` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    pub fn regCtrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base);
    }

    pub const CTRL_EN: u32 = 1 << 0;
    pub const CTRL_EXT_ENABLE: u32 = 1 << 1;
    pub const CTRL_EXT_CLOCK: u32 = 1 << 2;
    pub const CTRL_INT_EN: u32 = 1 << 3;

    pub fn regValue(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x04);
    }

    pub fn regReload(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x08);
    }

    pub fn regIntStatusClear(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x0c);
    }

    pub fn setEnable(self: Self, x: bool) void {
        if (x) {
            self.regCtrl.* |= CTRL_EN;
        } else {
            self.regCtrl.* &= ~CTRL_EN;
        }
    }

    pub fn setClockSource(self: Self, x: bool) void {
        if (x) {
            self.regCtrl.* |= CTRL_EXT_CLOCK;
        } else {
            self.regCtrl.* &= ~CTRL_EXT_CLOCK;
        }
    }

    pub fn setStartByExternalInput(self: Self, x: bool) void {
        if (x) {
            self.regCtrl.* |= CTRL_EXT_ENABLE;
        } else {
            self.regCtrl.* &= ~CTRL_EXT_ENABLE;
        }
    }

    pub fn setInterruptEnable(self: Self, x: bool) void {
        if (x) {
            self.regCtrl.* |= CTRL_INT_EN;
        } else {
            self.regCtrl.* &= ~CTRL_INT_EN;
        }
    }

    pub fn getValue(self: Self) u32 {
        return self.regValue().*;
    }

    pub fn setValue(self: Self, x: u32) void {
        self.regValue().* = x;
    }

    pub fn getReloadValue(self: Self) u32 {
        return self.regReload().*;
    }

    pub fn setReloadValue(self: Self, x: u32) void {
        self.regReload().* = x;
    }

    pub fn clearInterruptFlag(self: Self) void {
        self.regIntStatusClear().* = 1;
    }
};
