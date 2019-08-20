const format = @import("std").fmt.format;

/// Output a formatted text via a global debug output function.
pub fn warn(comptime fmt: []const u8, args: ...) void {
    if (cur_handler) |handler| {
        format({}, error{}, handler, fmt, args) catch unreachable;
    }
}

const WarnHandler = fn (void, []const u8) error{}!void;

var cur_handler: ?WarnHandler = null;

pub fn setWarnHandler(new_handler: ?WarnHandler) void {
    cur_handler = new_handler;
}
