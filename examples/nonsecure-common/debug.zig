const format = @import("std").fmt.format;
const OutStream = @import("std").io.OutStream;

const gateways = @import("../common/gateways.zig");

/// Output a formatted text via a Secure gateway.
pub fn warn(comptime fmt: []const u8, args: var) void {
    const out_stream = OutStream(void, error{}, warnInner){ .context = {} };
    format(out_stream, fmt, args) catch unreachable;
}

fn warnInner(ctx: void, data: []const u8) error{}!usize {
    _ = gateways.debugOutput(data.len, data.ptr, 0, 0);
    return data.len;
}
