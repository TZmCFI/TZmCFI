export fn __TCPrivateShadowPush() linksection(".gnu.sgstubs") void {
    // r12 = continuation
    asm volatile (
        \\ sg
        \\
        \\ # Mark that `r12` is a Non-Secure address.
        \\ bic r12, #1
        \\ bxns r12
    );
}

export fn __TCPrivateShadowAssertReturn() linksection(".gnu.sgstubs") void {
    asm volatile (
        \\ sg
        \\ # TODO: validate `lr`
        \\ bxns lr
    );
}

export fn __TCPrivateShadowAssert() linksection(".gnu.sgstubs") void {
    asm volatile (
        \\ sg
        \\ # Calling a secure gateway automatically clears LR[0]. It's useful
        \\ # for doing `bxns lr` in Secure code, but when used in Non-Secure
        \\ # mode, it just causes SecureFault.
        \\ orr lr, #1
        \\
        \\ # TODO: validate `lr`
        \\
        \\ # Mark that `r12` is a Non-Secure address.
        \\ bic r12, #1
        \\ bxns r12
    );
}

// Export the gateway functions to Non-Secure
comptime {
    @export("__acle_se___TCPrivateShadowPush", __TCPrivateShadowPush, .Strong);
    @export("__acle_se___TCPrivateShadowAssertReturn", __TCPrivateShadowAssertReturn, .Strong);
    @export("__acle_se___TCPrivateShadowAssert", __TCPrivateShadowAssert, .Strong);
}
