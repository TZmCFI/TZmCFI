// Utility functions for non-Secure applications
// ----------------------------------------------------------------------------

/// Implements `TCRaisePrivilege` defined in `Gateway.h`.
pub export fn TCRaisePrivilege() linksection(".gnu.sgstubs") callconv(.Naked) noreturn {
    // This `asm` block provably never returns
    @setRuntimeSafety(false);

    asm volatile (
        \\ .syntax unified
        \\
        \\ sg
        \\
        \\ mrs r0, control_ns
        \\ bic r0, #1
        \\ msr control_ns, r0
        \\ mov r0, #0
        \\
        \\ bxns lr
    );
    unreachable;
}

comptime {
    @export(TCRaisePrivilege, .{ .name = "__acle_se_TCRaisePrivilege", .linkage = .Strong });
}
