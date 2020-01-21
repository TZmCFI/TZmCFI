// The root source file of TZmCFI Monitor.
//
// This module produces three kinds of exports:
//
// 1. The secure API (`Secure.h`) - This includes a set of functions to be
//    called by the bootloader running in Secure mode.
//
//    This API is also exposed via this module so that it can be consumed by
//    Zig code.
//
// 2. The gateway API (`Gateway.h`) - This is meant to be used by a Non-Secure
//    operating system to manage execution contexts and the system state.
//    Usually, the application developers have to manually insert calls to this
//    API.
//
// 3. The private gateway API (`PrivateGateway.h`) - This is not intended to be
//    called from an application or operating system but rather to be called by
//    CFI instrumentation code embedded in Non-Secure code.
//
const debug = @import("monitor/debug.zig");
const ffi = @import("monitor/ffi.zig");
const shadowexcstack = @import("monitor/shadowexcstack.zig");
const shadowstack = @import("monitor/shadowstack.zig");
const threads = @import("monitor/threads.zig");
const profiler = @import("monitor/profiler.zig");
const options = @import("monitor/options.zig");
const nsutils = @import("monitor/nsutils.zig");

// Make sure symbols are exported
comptime {
    _ = shadowstack;
    _ = threads;
    _ = profiler;
    _ = nsutils;
}

pub const TCResult = ffi.TCResult;
pub const TCThread = ffi.TCThread;
pub const TCThreadCreateFlags = ffi.TCThreadCreateFlags;
pub const TCThreadCreateInfo = ffi.TCThreadCreateInfo;

pub const TCInitialize = shadowexcstack.TCInitialize;

pub const setWarnHandler = debug.setWarnHandler;

pub const LogLevel = options.LogLevel;
