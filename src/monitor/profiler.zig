// Statistical srofiler
// ----------------------------------------------------------------------------
const std = @import("std");
const formatIntBuf = std.fmt.formatIntBuf;
const FormatOptions = std.fmt.FormatOptions;
// ----------------------------------------------------------------------------
const arm_cmse = @import("../drivers/arm_cmse.zig");
// ----------------------------------------------------------------------------
const log = @import("debug.zig").log;

pub const ACTIVE: bool = @import("options.zig").ENABLE_PROFILER;
// ----------------------------------------------------------------------------

pub const Event = enum(u8) {
    EnterInterrupt = 0,
    LeaveInterrupt,
    ShadowPush,
    ShadowAssert,
    ShadowAssertReturn,

    Count,
};

const num_event_types = @enumToInt(Event.Count);

const event_short_names = [_][]const u8{
    "EntInt",
    "LeaInt",
    "ShPush",
    "ShAsrt",
    "ShAsrtRet",
};

var event_count = [1]usize{0} ** num_event_types;
var profile_running: u8 = 0;

pub inline fn markEvent(e: Event) void {
    if (@atomicLoad(u8, &profile_running, .Monotonic) != 0) {
        _ = @atomicRmw(usize, &event_count[@enumToInt(e)], .Add, 1, .Monotonic);
    }
}

// Non-Secure application interface
// ----------------------------------------------------------------------------
fn TCDebugStartProfiler(_1: usize, _2: usize, _3: usize, _4: usize) callconv(.C) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0x3df2417d;
    }

    for (event_count) |*count| {
        _ = @atomicRmw(usize, count, .Xchg, 0, .Monotonic);
    }
    _ = @atomicRmw(u8, &profile_running, .Xchg, 1, .Monotonic);

    return 0;
}

fn TCDebugStopProfiler(_1: usize, _2: usize, _3: usize, _4: usize) callconv(.C) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0xd87589d4;
    }

    _ = @atomicRmw(u8, &profile_running, .Xchg, 0, .Monotonic);

    return 0;
}

fn TCDebugDumpProfile(_1: usize, _2: usize, _3: usize, _4: usize) callconv(.C) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0x767e7180;
    }

    log(.Critical, "# TCDebugDumpProfile\r\n", .{});

    var buf: [10]u8 = undefined;

    comptime var line: u32 = 1;
    inline while (line <= 3) : (line += 1) {
        log(.Critical, " | ", .{});

        var i: usize = 0;
        while (i < event_short_names.len) : (i += 1) {
            const width = event_short_names[i].len;
            if (line == 1) {
                log(.Critical, "{}", .{event_short_names[i]});
            } else if (line == 2) {
                log(.Critical, "{}:", .{("-" ** 10)[0 .. width - 1]});
            } else if (line == 3) {
                const len = formatIntBuf(&buf, event_count[i], 10, false, FormatOptions{});
                log(.Critical, "{}", .{(" " ** 10)[0 .. width - len]});
                log(.Critical, "{}", .{buf[0..len]});
            }
            log(.Critical, " | ", .{});
        }

        log(.Critical, "\r\n", .{});
    }

    return 0;
}

comptime {
    arm_cmse.exportNonSecureCallable("TCDebugStartProfiler", TCDebugStartProfiler);
    arm_cmse.exportNonSecureCallable("TCDebugStopProfiler", TCDebugStopProfiler);
    arm_cmse.exportNonSecureCallable("TCDebugDumpProfile", TCDebugDumpProfile);
}
