const root = @import("root");

pub const ENABLE_PROFILER: bool = if (@hasDecl(root, "TC_ENABLE_PROFILER"))
    root.TC_ENABLE_PROFILER
else
    false;

/// Controls whether the shadow stack return routine checks the integrity of a
/// return address (and aborts on failure) or just discards a non-trustworthy
/// return address.
pub const ABORTING_SHADOWSTACK: bool = if (@hasDecl(root, "TC_ABORTING_SHADOWSTACK"))
    root.TC_ABORTING_SHADOWSTACK
else
    false;

/// Compile-time log level.
pub const LOG_LEVEL: LogLevel = if (@hasDecl(root, "TC_LOG_LEVEL"))
    if (@TypeOf(root.TC_LOG_LEVEL) == LogLevel)
        root.TC_LOG_LEVEL
    else
        @field(LogLevel, root.TC_LOG_LEVEL)
else
    LogLevel.Critical;

pub const LogLevel = enum(u8) {
    /// This log level outputs every single log message.
    Trace = 0,

    /// Produces fewer log messages than `Trace`.
    Warning = 1,

    /// Only outputs important message, such as a profiling result when
    /// `TC_ENABLE_PROFILER` is enabled.
    Critical = 2,

    /// Disables the log output. All log messages are removed at compile-time.
    None = 3,
};

pub fn isLogLevelEnabled(level: LogLevel) bool {
    return @enumToInt(level) >= @enumToInt(LOG_LEVEL);
}

/// A function for configuring MPU guard regions for a shadow stack.
///
/// The two parameters `start` and `end` specify the starting and ending
/// addresses of a shadow stack. `start` and `end` are aligned to 32-byte blocks
/// and `start` is less than `end`. The callee must configure MPU to ensure
/// memory access at the following ranges fails and triggers an exception:
///
///  - `start - 32 .. start`
///  - `end .. end + 32`
///
/// The intended way to implement this is to set up at least 3 MPU regions: the
/// first one at `start - 32 .. start`, the second one at `end .. end + 32`, and
/// the last one overlapping both of them. Memory access always fails regardless
/// of privileged/unprivileged modes in a region overlap.
pub const setShadowStackGuard: fn (usize, usize) void = root.tcSetShadowStackGuard;

/// A function for removing MPU guard regions for a shadow stack.
pub const resetShadowStackGuard: fn (usize, usize) void = root.tcResetShadowStackGuard;
