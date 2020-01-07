const arm_m = @import("arm_m");
const lpc_protchecker = @import("lpc_protchecker.zig");
const flexcomm_driver = @import("flexcomm.zig");

/// Security access rules for flash memory. Each flash sector is 32 kbytes.
/// There are 20 FLASH sectors in total.
pub const mpc_flash = lpc_protchecker.Mpc {
    .base = 0x500ac010,
    .block_size_shift = 15,
    .num_blocks = 20,
};

/// Security access rules for ROM memory. Each ROM sector is 4 kbytes. There
/// are 32 ROM sectors in total.
pub const mpc_rom = lpc_protchecker.Mpc {
    .base = 0x500ac024,
    .block_size_shift = 12,
    .num_blocks = 32,
};

/// Security access rules for RAMX. Each RAMX sub region is 4 kbytes.
pub const mpc_ramx = lpc_protchecker.Mpc {
    .base = 0x500ac040,
    .block_size_shift = 12,
    .num_blocks = 8,
};

/// Security access rules for RAM0. Each RAMX sub region is 4 kbytes.
pub const mpc_ram0 = lpc_protchecker.Mpc {
    .base = 0x500ac060,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM1. Each RAM1 sub region is 4 kbytes.
pub const mpc_ram1 = lpc_protchecker.Mpc {
    .base = 0x500ac080,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM2. Each RAM2 sub region is 4 kbytes.
pub const mpc_ram2 = lpc_protchecker.Mpc {
    .base = 0x500ac0a0,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM3. Each RAM3 sub region is 4 kbytes.
pub const mpc_ram3 = lpc_protchecker.Mpc {
    .base = 0x500ac0c0,
    .block_size_shift = 12,
    .num_blocks = 16,
};

/// Security access rules for RAM4. Each RAM4 sub region is 4 kbytes.
pub const mpc_ram4 = lpc_protchecker.Mpc {
    .base = 0x500ac0e0,
    .block_size_shift = 12,
    .num_blocks = 4,
};

pub const PpcApbBridge0 = struct {
    base: usize,

    const Self = @This();

    fn regCtrl1(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x4);
    }

    pub fn setCTimer0Rule(self: Self, rule: lpc_protchecker.ProtCheckerRule) void {
        lpc_protchecker.setRule(self.regCtrl1(), 0, rule);
    }

    pub fn setCTimer1Rule(self: Self, rule: lpc_protchecker.ProtCheckerRule) void {
        lpc_protchecker.setRule(self.regCtrl1(), 4, rule);
    }
};

pub const ppc_apb_bridge0 = PpcApbBridge0 { .base = 0x500AC100 };

pub const Flexcomm = flexcomm_driver.Flexcomm;

/// Flexcomm instances (Secure alias)
pub const flexcomm = [8]Flexcomm {
    Flexcomm { .base = 0x50086000 },
    Flexcomm { .base = 0x50087000 },
    Flexcomm { .base = 0x50088000 },
    Flexcomm { .base = 0x50089000 },
    Flexcomm { .base = 0x5008a000 },
    Flexcomm { .base = 0x50096000 },
    Flexcomm { .base = 0x50097000 },
    Flexcomm { .base = 0x50098000 },
};

/// The number of hardware interrupt lines.
pub const num_irqs = 60;

pub const irqs = struct {
    pub const CTimer0_IRQn = arm_m.irqs.interruptIRQn(10);
    pub const CTimer1_IRQn = arm_m.irqs.interruptIRQn(11);

    /// Get the descriptive name of an exception number. Returns `null` if
    /// the exception number is not known by this module.
    pub fn getName(comptime i: usize) ?[]const u8 {
        switch (i) {
            CTimer0_IRQn => return "CTimer0",
            CTimer1_IRQn => return "CTimer1",
            else => return arm_m.irqs.getName(i),
        }
    }
};
