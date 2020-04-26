// ----------------------------------------------------------------------------
const format = @import("std").fmt.format;
const OutStream = @import("std").io.OutStream;
// ----------------------------------------------------------------------------
const options = @import("options.zig");
const LogLevel = options.LogLevel;
const isLogLevelEnabled = options.isLogLevelEnabled;
// ----------------------------------------------------------------------------

/// Output a formatted text via a global debug output function.
pub fn log(comptime level: LogLevel, comptime fmt: []const u8, args: var) void {
    if (comptime isLogLevelEnabled(level)) {
        if (cur_handler) |handler| {
            const out_stream = GlobalWarnHandlerStream{ .context = handler };
            format(out_stream, fmt, args) catch unreachable;
        }
    }
}

const GlobalWarnHandlerStream = OutStream(WarnHandler, error{}, globalWarnHandlerStreamWrite);

fn globalWarnHandlerStreamWrite(handler: WarnHandler, data: []const u8) error{}!usize {
    try handler({}, data);
    return data.len;
}

const WarnHandler = fn (void, []const u8) error{}!void;

var cur_handler: ?WarnHandler = null;

pub fn setWarnHandler(new_handler: ?WarnHandler) void {
    cur_handler = new_handler;
}
