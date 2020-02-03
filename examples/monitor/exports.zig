// Prototype definition for `monitor.zig`
pub const WarnHandler = extern fn ([*]const u8, usize) void;

pub extern fn TCXInitializeMonitor(warn_handler: WarnHandler) void;
