// Utility functions for non-Secure applications
// ----------------------------------------------------------------------------

/// Implements `TCRaisePrivilege` defined in `Gateway.h`.
pub export nakedcc fn TCRaisePrivilege() linksection(".gnu.sgstubs") noreturn {
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
        \\ bx lr
    );
    unreachable;
}

comptime {
    @export("__acle_se_TCRaisePrivilege", TCRaisePrivilege, .Strong);
}
