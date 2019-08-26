// The root source file for the "rtosbasic" example application.
export const _ = @import("nonsecure-rtosbasic/main.zig");

const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
