extern var __privileged_sram_start__: usize;
extern var __privileged_sram_end__: usize;

pub fn init() void {
    // Clear the privileged data to 0 as the startup code is only set to
    // clear the non-privileged bss.
    const start = @ptrCast([*]u8, &__privileged_sram_start__);
    const end = @ptrCast([*]u8, &__privileged_sram_end__);
    @memset(start, 0, @ptrToInt(end) - @ptrToInt(start));
}
