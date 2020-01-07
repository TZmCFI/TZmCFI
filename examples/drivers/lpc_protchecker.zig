/// The device driver for MPC (Memory Protection Checker) and PPC (Peripheral
/// PRotection Checker) found in LPC microcontrollers including LPC55S69.

pub const ProtCheckerRule = enum {
    /// Non-secure and non-privileged user access allowed.
    NsNonpriv = 0,
    /// Non-secure and privileged access allowed.
    NsPriv = 1,
    /// Secure and non-privileged user access allowed.
    SNonpriv = 2,
    /// Secure and privileged user access allowed.
    SPriv = 3,
};

/// Set a single security rule.
pub fn setRule(r: *volatile u32, bit: u5, rule: ProtCheckerRule) void {
    r.* = (r.* & ~(@as(u32, 0b11) << bit)) | (@as(u32, @enumToInt(rule)) << bit);
}

/// Represents a single instance of a memory protection checker.
pub const Mpc = struct {
    base: usize,
    block_size_shift: u5,
    num_blocks: u32,

    const Self = @This();

    /// Set the security rule of a relative address range.
    ///
    /// The range might be rounded to the block size the hardware is configured
    /// with.
    pub fn setRuleInRange(self: Self, start: u32, end: u32, rule: ProtCheckerRule) void {
        self.updateRange(start, end, Masks{ 0xcccccccc, @enumToInt(u32, rule) * 0x11111111 });
    }

    fn updateLut(self: Self, gr: u32, masks: Masks) void {
        const lut = @intToPtr(*volatile u32, self.base + gr * 4);
        lut.* = (lut.* & masks[0]) ^ masks[1];
    }

    fn updateRange(self: Self, startBytes: u32, endBytes: u32, masks: Masks) void {
        // (Silently) round to the block size used by the hardware
        const shift = self.block_size_shift();
        const start = startBytes >> shift;
        const end = endBytes >> shift;

        if (start >= end) {
            return;
        }

        if (end > self.num_blocks) {
            unreachable;
        }

        // Each 32-bit register contains the information for 8 blocks
        const start_group = start / 32 * 4;
        const end_group = end / 32 * 4;

        if (start_group == end_group) {
            const masks2 = filterMasks(masks, onesFrom(start % 32) ^ onesFrom(end % 32));
            self.updateLut(start_group, masks2);
        } else {
            var group = start_group;

            if ((start % 32) != 0) {
                const cap_masks = filterMasks(masks, onesFrom(start % 32));
                self.updateLut(group, cap_masks);

                group += 1;
            }

            while (group < end_group) {
                self.updateLut(group, masks);

                group += 1;
            }

            if ((end % 32) != 0) {
                const cap_masks = filterMasks(masks, ~onesFrom(end % 32));
                self.updateLut(group, cap_masks);
            }
        }
    }
};


/// AND and XOR masks.
const Masks = [2]u32;

fn filterMasks(masks: Masks, filter: u32) Masks {
    return Masks{ masks[0] & ~filter, masks[1] & filter };
}

/// Returns `0b11111000...000` where the number of trailing zeros is specified
/// by `pos`. `pos` must be in `[0, 31]`.
fn onesFrom(pos: u32) u32 {
    return @as(u32, 0xffffffff) << @intCast(u5, pos);
}
