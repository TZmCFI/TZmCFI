// The root source file for the Secure part of this project.
export const _ = @import("secure/main.zig");

const an505 = @import("drivers/an505.zig");
const builtin = @import("builtin");

// Pass build options to `tzmcfi`, which picks them up via `@import("root")`
pub const TC_ENABLE_PROFILER = @import("build_options").ENABLE_PROFILE;

/// The global panic handler. (The compiler looks for `pub fn panic` in the root
/// source file. See `zig/std/special/panic.zig`.)
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    an505.uart0_s.print("panic: {}\r\n", msg);
    @breakpoint();
    unreachable;
}
