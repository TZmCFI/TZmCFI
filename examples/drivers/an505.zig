const arm_m = @import("arm_m");

const Pl011 = @import("pl011.zig").Pl011;
const TzMpc = @import("tz_mpc.zig").TzMpc;
const CmsdkTimer = @import("cmsdk_timer.zig").CmsdkTimer;

/// UART 0 (secure) - J10 port
pub const uart0 = Pl011.withBase(0x40200000);
pub const uart0_s = Pl011.withBase(0x50200000); // Secure alias

// CMSDK timer
pub const timer0 = CmsdkTimer.withBase(0x40000000);
pub const timer0_s = CmsdkTimer.withBase(0x50000000); // Secure alias
pub const timer1 = CmsdkTimer.withBase(0x40001000);
pub const timer1_s = CmsdkTimer.withBase(0x50001000); // Secure alias

pub const ssram1_mpc = TzMpc.withBase(0x58007000);
pub const ssram2_mpc = TzMpc.withBase(0x58008000);
pub const ssram3_mpc = TzMpc.withBase(0x58009000);

/// Security Privilege Control Block.
///
/// This is a part of Arm CoreLink SSE-200 Subsystem for Embedded.
pub const Spcb = struct {
    base: usize,

    const Self = @This();

    /// Construct a `Spcb` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    /// Secure Privilege Controller Secure Configuration Control register.
    pub fn regSpcsecctrl(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x000);
    }

    /// Bus Access wait control after reset.
    pub fn regBuswait(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x004);
    }

    /// Security Violation Response Configuration register.
    pub fn regSecrespcfg(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x010);
    }

    /// Non Secure Callable Configuration for IDAU.
    pub fn regNsccfg(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x014);
    }

    pub const NSCCFG_RAMNSC: u32 = 1 << 1;
    pub const NSCCFG_CODENSC: u32 = 1 << 0;

    /// Non-secure Access AHB slave Peripheral Protection Control #0.
    pub fn regAhbnsppcN(self: Self) *volatile [1]u32 {
        return @intToPtr(*volatile [1]u32, self.base + 0x050);
    }

    /// Expansion 0–3 Non-Secure Access AHB slave Peripheral Protection Control.
    pub fn regAhbnsppcexpN(self: Self) *volatile [4]u32 {
        return @intToPtr(*volatile [4]u32, self.base + 0x060);
    }

    /// Non-secure Access APB slave Peripheral Protection Control #0–1.
    pub fn regApbnsppcN(self: Self) *volatile [2]u32 {
        return @intToPtr(*volatile [2]u32, self.base + 0x070);
    }

    /// Expansion 0–3 Non-Secure Access APB slave Peripheral Protection Control.
    pub fn regApbnsppcexpN(self: Self) *volatile [4]u32 {
        return @intToPtr(*volatile [4]u32, self.base + 0x080);
    }

    /// Secure Unprivileged Access AHB slave Peripheral Protection Control #0.
    pub fn regAhbsppcN(self: Self) *volatile [1]u32 {
        return @intToPtr(*volatile [1]u32, self.base + 0x090);
    }

    /// Expansion 0–3 Secure Unprivileged Access AHB slave Peripheral Protection Control.
    pub fn regAhbsppcexpN(self: Self) *volatile [4]u32 {
        return @intToPtr(*volatile [4]u32, self.base + 0x0a0);
    }

    /// Secure Unprivileged Access APB slave Peripheral Protection Control #0–1.
    pub fn regApbsppcN(self: Self) *volatile [2]u32 {
        return @intToPtr(*volatile [2]u32, self.base + 0x0b0);
    }

    /// Expansion 0–3 Secure Unprivileged Access APB slave Peripheral Protection Control.
    pub fn regApbsppcexpN(self: Self) *volatile [4]u32 {
        return @intToPtr(*volatile [4]u32, self.base + 0x0c0);
    }

    pub const Bus = enum {
        Ahb,
        AhbExp,
        Apb,
        ApbExp,
    };
    pub const PpcIface = struct {
        bus: Bus,
        group: usize,
        num: usize,
    };
    pub const PpcAccess = enum {
        NonSecure,
        SecureUnprivileged,
    };

    pub fn setPpcAccess(self: Self, iface: PpcIface, access: PpcAccess, allow: bool) void {
        const reg = switch (access) {
            .NonSecure => switch (iface.bus) {
                .Ahb => &self.regAhbnsppcN()[iface.group],
                .AhbExp => &self.regAhbnsppcexpN()[iface.group],
                .Apb => &self.regApbnsppcN()[iface.group],
                .ApbExp => &self.regApbnsppcexpN()[iface.group],
            },
            .SecureUnprivileged => switch (iface.bus) {
                .Ahb => &self.regAhbsppcN()[iface.group],
                .AhbExp => &self.regAhbsppcexpN()[iface.group],
                .Apb => &self.regApbsppcN()[iface.group],
                .ApbExp => &self.regApbsppcexpN()[iface.group],
            },
        };
        if (allow) {
            reg.* |= u32(1) << @intCast(u5, iface.num);
        } else {
            reg.* &= ~(u32(1) << @intCast(u5, iface.num));
        }
    }
};

/// Represents an instance of Security Privilege Control Block.
pub const spcb = Spcb.withBase(0x50080000);

/// Non-Secure Privilege Control Block.
///
/// This is a part of Arm CoreLink SSE-200 Subsystem for Embedded.
pub const Nspcb = struct {
    base: usize,

    const Self = @This();

    /// Construct a `Spcb` object using the specified MMIO base address.
    pub fn withBase(base: usize) Self {
        return Self{ .base = base };
    }

    /// Non-secure Access AHB slave Peripheral Protection Control #0.
    pub fn regAhbnsppcN(self: Self) *volatile [1]u32 {
        return @intToPtr(*volatile [1]u32, self.base + 0x050);
    }

    /// Non-Secure Unprivileged Access AHB slave Peripheral Protection Control #0.
    pub fn regAhbnspppcN(self: Self) *volatile [1]u32 {
        return @intToPtr(*volatile [1]u32, self.base + 0x090);
    }

    /// Expansion 0–3 Non-Secure Unprivileged Access AHB slave Peripheral Protection Control.
    pub fn regAhbnspppcexpN(self: Self) *volatile [4]u32 {
        return @intToPtr(*volatile [4]u32, self.base + 0x0a0);
    }

    /// Non-Secure Unprivileged Access APB slave Peripheral Protection Control #0–1.
    pub fn regApbnspppcN(self: Self) *volatile [2]u32 {
        return @intToPtr(*volatile [2]u32, self.base + 0x0b0);
    }

    /// Expansion 0–3 Non-Secure Unprivileged Access APB slave Peripheral Protection Control.
    pub fn regApbnspppcexpN(self: Self) *volatile [4]u32 {
        return @intToPtr(*volatile [4]u32, self.base + 0x0c0);
    }

    pub const Bus = Spcb.Bus;
    pub const PpcIface = Spcb.PpcIface;

    pub fn setPpcAccess(self: Self, iface: PpcIface, allow: bool) void {
        const reg =  switch (iface.bus) {
            .Ahb => &self.regAhbnspppcN()[iface.group],
            .AhbExp => &self.regAhbnspppcexpN()[iface.group],
            .Apb => &self.regApbnspppcN()[iface.group],
            .ApbExp => &self.regApbnspppcexpN()[iface.group],
        };
        if (allow) {
            reg.* |= u32(1) << @intCast(u5, iface.num);
        } else {
            reg.* &= ~(u32(1) << @intCast(u5, iface.num));
        }
    }
};

/// Represents an instance of Non-Secure Privilege Control Block.
pub const nspcb = Nspcb.withBase(0x40080000);

/// Represents peripherals controlled by PPC.
///
/// Each constant is of type `Spcb.PpcIface` and can be passed to
/// `spcb.setPpcAccess` to allow or disallow Non-Secure or Secure unprivileged
/// access to the connected peripheral.
pub const ppc = struct {
    fn iface(bus: Spcb.Bus, group: usize, num: usize) Spcb.PpcIface {
        return Spcb.PpcIface{ .bus = bus, .group = group, .num = num };
    }

    pub const timer0_ = iface(.Apb, 0, 0);
    pub const timer1_ = iface(.Apb, 0, 1);
    pub const dual_timer_ = iface(.Apb, 0, 2);
    pub const mhu0 = iface(.Apb, 0, 3);
    pub const mhu1 = iface(.Apb, 0, 4);
    pub const s32k_timer = iface(.Apb, 1, 0);
};

/// Represents expansion peripherals controlled by PPC.
///
/// Each constant is of type `Spcb.PpcIface` and can be passed to
/// `spcb.setPpcAccess` to allow or disallow Non-Secure or Secure unprivileged
/// access to the connected peripheral.
pub const ppc_exp = struct {
    fn iface(bus: Spcb.Bus, group: usize, num: usize) Spcb.PpcIface {
        return Spcb.PpcIface{ .bus = bus, .group = group, .num = num };
    }

    pub const ssram1_mpc = iface(.ApbExp, 0, 0);
    pub const ssram2_mpc = iface(.ApbExp, 0, 1);
    pub const ssram3_mpc = iface(.ApbExp, 0, 2);
    pub const spi0 = iface(.ApbExp, 1, 0);
    pub const spi1 = iface(.ApbExp, 1, 1);
    pub const spi2 = iface(.ApbExp, 1, 2);
    pub const spi3 = iface(.ApbExp, 1, 3);
    pub const spi4 = iface(.ApbExp, 1, 4);
    pub const uart0 = iface(.ApbExp, 1, 5);
    pub const uart1 = iface(.ApbExp, 1, 6);
    pub const uart2 = iface(.ApbExp, 1, 7);
    pub const uart3 = iface(.ApbExp, 1, 8);
    pub const uart4 = iface(.ApbExp, 1, 9);
    pub const i2c0 = iface(.ApbExp, 1, 10);
    pub const i2c1 = iface(.ApbExp, 1, 11);
    pub const i2c2 = iface(.ApbExp, 1, 12);
    pub const i2c3 = iface(.ApbExp, 1, 13);
    pub const scc = iface(.ApbExp, 2, 0);
    pub const audio = iface(.ApbExp, 2, 1);
    pub const fpgaio = iface(.ApbExp, 2, 2);
    pub const vga = iface(.AhbExp, 0, 0);
    pub const gpio0 = iface(.AhbExp, 0, 1);
    pub const gpio1 = iface(.AhbExp, 0, 2);
    pub const gpio2 = iface(.AhbExp, 0, 3);
    pub const gpio3 = iface(.AhbExp, 0, 4);
    pub const dma0 = iface(.AhbExp, 1, 0);
    pub const dma1 = iface(.AhbExp, 1, 1);
    pub const dma2 = iface(.AhbExp, 1, 2);
    pub const dma3 = iface(.AhbExp, 1, 3);
};

/// The number of hardware interrupt lines.
pub const num_irqs = 124;

pub const irqs = struct {
    pub const Timer0_IRQn = arm_m.irqs.interruptIRQn(3);
    pub const Timer1_IRQn = arm_m.irqs.interruptIRQn(4);
    pub const DualTimer_IRQn = arm_m.irqs.interruptIRQn(5);

    /// Get the descriptive name of an exception number. Returns `null` if
    /// the exception number is not known by this module.
    pub fn getName(comptime i: usize) ?[]const u8 {
        switch (i) {
            Timer0_IRQn => return "Timer0",
            Timer1_IRQn => return "Timer1",
            DualTimer_IRQn => return "DualTimer",
            else => return arm_m.irqs.getName(i),
        }
    }
};
