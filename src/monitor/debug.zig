// ----------------------------------------------------------------------------
const format = @import("std").fmt.format;
// ----------------------------------------------------------------------------
const options = @import("options.zig");
const LogLevel = options.LogLevel;
const isLogLevelEnabled = options.isLogLevelEnabled;
// ----------------------------------------------------------------------------

/// Output a formatted text via a global debug output function.
pub fn log(comptime level: LogLevel, comptime fmt: []const u8, args: ...) void {
    if (comptime isLogLevelEnabled(level)) {
        if (cur_handler) |handler| {
            format({}, error{}, handler, fmt, args) catch unreachable;
        }
    }
}

const WarnHandler = fn (void, []const u8) error{}!void;

var cur_handler: ?WarnHandler = null;

pub fn setWarnHandler(new_handler: ?WarnHandler) void {
    cur_handler = new_handler;
}
