// The root source file for the Secure part of this project.
export const main_module = @import("secure/main.zig");

const builtin = @import("builtin");

// Pass build options to `tzmcfi`, which picks them up via `@import("root")`
// See `src/monitor/options.zig`.
pub const TC_ENABLE_PROFILER = @import("build_options").ENABLE_PROFILE;
pub const TC_ABORTING_SHADOWSTACK = @import("build_options").ABORTING_SHADOWSTACK;
pub const TC_LOG_LEVEL = @import("build_options").LOG_LEVEL;

// `tzmcfi` hooks
pub const tcSetShadowStackGuard = main_module.tcSetShadowStackGuard;
pub const tcResetShadowStackGuard = main_module.tcResetShadowStackGuard;

/// The global panic handler. (The compiler looks for `pub fn panic` in the root
/// source file. See `zig/std/special/panic.zig`.)
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    main_module.port.print("panic: {}\r\n", msg);
    @breakpoint();
    unreachable;
}
