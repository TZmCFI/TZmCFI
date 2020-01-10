const an505 = @import("../../drivers/an505.zig");
const VecTable = @import("../../common/vectable.zig").VecTable;

pub const BoardVecTable = VecTable(an505.num_irqs, an505.irqs.getName);
