// This source file defines a panic handler shared by our Non-Secure
// applications.
//
// The compiler looks for `pub fn panic` in the root source file. (See
// `zig/std/special/panic.zig`.)
const builtin = @import("builtin");
const warn = @import("debug.zig").warn;

pub const StackTrace = builtin.StackTrace;

/// The global panic handler.
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    warn("NS panic: {}\r\n", msg);
    @breakpoint();
    unreachable;
}
