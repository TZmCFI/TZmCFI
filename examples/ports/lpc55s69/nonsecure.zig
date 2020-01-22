const lpc55s69 = @import("../../drivers/lpc55s69.zig");

extern var __privileged_sram_start__: usize;
extern var __privileged_sram_end__: usize;

const Syscon = lpc55s69.Syscon;
const syscon = lpc55s69.syscon_ns;

pub fn init() void {
    // Clear the privileged data to 0 as the startup code is only set to
    // clear the non-privileged bss.
    const start = @ptrCast([*]u8, &__privileged_sram_start__);
    const end = @ptrCast([*]u8, &__privileged_sram_end__);
    @memset(start, 0, @ptrToInt(end) - @ptrToInt(start));

    // Supply clock to CTimer0/CTimer1
    syscon.regAhbclkctrlset1().* = Syscon.AHBCLKCTRL1_TIMER0 | Syscon.AHBCLKCTRL1_TIMER1;

    // Configure CTimer0/CTimer1 to use the same clock as the processor
    syscon.regCtimerclkseln(0).* = Syscon.CTIMERCLKSEL_SEL_MAIN_CLOCK;
    syscon.regCtimerclkseln(1).* = Syscon.CTIMERCLKSEL_SEL_MAIN_CLOCK;
}
