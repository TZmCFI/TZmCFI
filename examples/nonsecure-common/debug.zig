const format = @import("std").fmt.format;

const gateways = @import("../common/gateways.zig");

/// Output a formatted text via a Secure gateway.
pub fn warn(comptime fmt: []const u8, args: ...) void {
    format({}, error{}, warnInner, fmt, args) catch unreachable;
}

fn warnInner(ctx: void, data: []const u8) error{}!void {
    _ = gateways.debugOutput(data.len, data.ptr, 0, 0);
}
