// The root source file for the Secure part of this project.
export const _ = @import("secure/main.zig");

const an505 = @import("drivers/an505.zig");
const builtin = @import("builtin");

/// The global panic handler. (The compiler looks for `pub fn panic` in the root
/// source file. See `zig/std/special/panic.zig`.)
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    an505.uart0.print("panic: {}\r\n", msg);
    @breakpoint();
    unreachable;
}
