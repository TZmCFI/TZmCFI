// Statistical srofiler
// ----------------------------------------------------------------------------
const arm_cmse = @import("../drivers/arm_cmse.zig");
// ----------------------------------------------------------------------------
const log = @import("debug.zig").log;

pub const ACTIVE: bool = @import("options.zig").ENABLE_PROFILER;
// ----------------------------------------------------------------------------

// TODO

// Non-Secure application interface
// ----------------------------------------------------------------------------
extern fn TCDebugStartProfiler(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0x3df2417d;
    }

    log(.Critical, "TODO: TCDebugStartProfiler\r\n");

    return 0;
}

extern fn TCDebugStopProfiler(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0xd87589d4;
    }

    log(.Critical, "TODO: TCDebugStopProfiler\r\n");

    return 0;
}

extern fn TCDebugDumpProfile(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0x767e7180;
    }

    log(.Critical, "TODO: TCDebugDumpProfile\r\n");

    return 0;
}

comptime {
    arm_cmse.exportNonSecureCallable("TCDebugStartProfiler", TCDebugStartProfiler);
    arm_cmse.exportNonSecureCallable("TCDebugStopProfiler", TCDebugStopProfiler);
    arm_cmse.exportNonSecureCallable("TCDebugDumpProfile", TCDebugDumpProfile);
}
