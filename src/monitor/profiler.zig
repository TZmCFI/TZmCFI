// Statistical srofiler
// ----------------------------------------------------------------------------
const arm_cmse = @import("../drivers/arm_cmse.zig");
// ----------------------------------------------------------------------------
const warn = @import("debug.zig").warn;

const root = @import("root");
pub const ACTIVE: bool = if (@hasDecl(root, "TC_ENABLE_PROFILER"))
    root.TC_ENABLE_PROFILER else false;
// ----------------------------------------------------------------------------

// TODO

// Non-Secure application interface
// ----------------------------------------------------------------------------
extern fn TCDebugStartProfiler(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0x3df2417d;
    }

    warn("TODO: TCDebugStartProfiler\r\n");

    return 0;
}

extern fn TCDebugStopProfiler(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0xd87589d4;
    }

    warn("TODO: TCDebugStopProfiler\r\n");

    return 0;
}

extern fn TCDebugDumpProfile(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    if (!ACTIVE) {
        // work-around function merging (which causes `sg` to disappear)
        return 0x767e7180;
    }

    warn("TODO: TCDebugDumpProfile\r\n");

    return 0;
}

comptime {
    arm_cmse.exportNonSecureCallable("TCDebugStartProfiler", TCDebugStartProfiler);
    arm_cmse.exportNonSecureCallable("TCDebugStopProfiler", TCDebugStopProfiler);
    arm_cmse.exportNonSecureCallable("TCDebugDumpProfile", TCDebugDumpProfile);
}
