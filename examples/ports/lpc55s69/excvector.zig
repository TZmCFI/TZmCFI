const lpc55s69 = @import("../../drivers/lpc55s69.zig");
const VecTable = @import("../../common/vectable.zig").VecTable;

pub const BoardVecTable = VecTable(lpc55s69.num_irqs, lpc55s69.irqs.getName);
