const lpc55s69 = @import("../../drivers/lpc55s69.zig");
const VecTable = @import("../../common/vectable.zig").VecTable;

pub const BoardVecTable = VecTable(lpc55s69.num_irqs, lpc55s69.irqs.getName);

// zig fmt: off
pub const secure_board_vec_table = BoardVecTable.new()
    // 0x20 - The length of current image
    .setExcHandler(8, null)
    // 0x24 - Image Type. 0 = Normal image for unsecure boot
    .setExcHandler(9, null)
    // 0x28 - Unused for image type 0
    .setExcHandler(10, null)
    // 0x34 - Unused for image type 0
    .setExcHandler(13, null);
// zig fmt: on
