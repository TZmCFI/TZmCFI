const format = @import("std").fmt.format;

/// Output a formatted text via a global debug output function.
pub fn warn(comptime fmt: []const u8, args: ...) void {
    format({}, error{}, warnInner, fmt, args) catch unreachable;
}

fn warnInner(ctx: void, data: []const u8) error{}!void {
    _ = gateways.debugOutput(data.len, data.ptr, 0, 0);
}
