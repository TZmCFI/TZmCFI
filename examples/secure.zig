// The root source file for the Secure part of this project.
const main_module = @import("secure/main.zig");
const builtin = @import("builtin");

/// The global panic handler. (The compiler looks for `pub fn panic` in the root
/// source file. See `zig/std/special/panic.zig`.)
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    main_module.port.print("panic: {}\r\n", .{msg});
    @breakpoint();
    unreachable;
}
