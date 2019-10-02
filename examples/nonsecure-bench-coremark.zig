// The root source file for the "bench-coremark" example application.
const std = @import("std");
const arm_m = @import("arm_m");
const warn = @import("nonsecure-common/debug.zig").warn;

// The (unprocessed) Non-Secure exception vector table.
// zig fmt: off
export const raw_exception_vectors linksection(".text.raw_isr_vector") =
    @import("nonsecure-common/excvector.zig").getDefaultBaremetal();
// zig fmt: on

comptime {
    _ = @import("nonsecure-bench-coremark/core_portme.zig");
    _ = @import("nonsecure-bench-coremark/cvt.zig");
}

// Zig panic handler. See `panicking.zig` for details.
const panicking = @import("nonsecure-common/panicking.zig");
pub fn panic(msg: []const u8, error_return_trace: ?*panicking.StackTrace) noreturn {
    panicking.panic(msg, error_return_trace);
}
