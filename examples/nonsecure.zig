// The root source file for the Non-Secure part of this project.
export const _ = @import("nonsecure/main.zig");

const builtin = @import("builtin");
const debugOutput = @import("nonsecure/debug.zig").debugOutput;

/// The global panic handler. (The compiler looks for `pub fn panic` in the root
/// source file. See `zig/std/special/panic.zig`.)
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    debugOutput("panic: {}\r\n", msg);
    @breakpoint();
    unreachable;
}
