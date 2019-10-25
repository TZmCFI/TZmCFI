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
    if (@typeOf(root.TC_LOG_LEVEL) == LogLevel)
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
