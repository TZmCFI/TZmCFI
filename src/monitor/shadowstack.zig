// The monitor part of the shadow stack implementation.
// ----------------------------------------------------------------------------
const builtin = @import("builtin");

const std = @import("std");
const Allocator = std.mem.Allocator;
// ----------------------------------------------------------------------------
const TCThreadCreateInfo = @import("ffi.zig").TCThreadCreateInfo;
const log = @import("debug.zig").log;
const options = @import("options.zig");
const ABORTING_SHADOWSTACK = options.ABORTING_SHADOWSTACK;
const setShadowStackGuard = options.setShadowStackGuard;

const markEvent = @import("profiler.zig").markEvent;
const ENABLE_PROFILER = @import("profiler.zig").ACTIVE;
// ----------------------------------------------------------------------------
export var g_shadow_stack_top: [*]usize = undefined;

const MPU_GRANULARITY = 32;
const STACK_ALIGN = MPU_GRANULARITY;
const STACK_SIZE = 16;

/// Bundles the state of a single instance of shadow stack.
pub const StackState = struct {
    top: [*]usize,
    frames: []usize,

    const Self = @This();

    /// Construct a `StackState` by allocating memory from `allocator`.
    pub fn new(allocator: *Allocator, create_info: ?*const TCThreadCreateInfo) !Self {
        // TODO: make stack size variable

        // Add two guard pages before and after the stack. MPU is used to detect
        // stack overflow/underflow by prohibiting memory access to the guard
        // pages.
        const gp_ents = MPU_GRANULARITY / @sizeOf(usize);

        var frames = try allocator.alignedAlloc(usize, STACK_ALIGN, STACK_SIZE + gp_ents * 2);

        // Exclude the guard pages
        frames = frames[gp_ents .. frames.len - gp_ents];

        for (frames) |*frame| {
            frame.* = 0;
        }

        return fromSlice(frames);
    }

    /// Release the memory allocated for `self`. `self` must have been created
    /// by `new(allocator, _)`.
    pub fn destroy(self: *const Self, allocator: *Allocator) void {
        allocator.free(self.frames);
    }

    fn fromSlice(frames: []usize) Self {
        return Self{
            .frames = frames,
            .top = @ptrCast([*]usize, &frames[0]),
        };
    }
};

pub fn saveState(state: *StackState) void {
    state.top = g_shadow_stack_top;
}

pub fn loadState(state: *const StackState) void {
    g_shadow_stack_top = state.top;

    // Configure MPU regions for the stack guard pages
    const start = @ptrToInt(&state.frames[0]);
    const end = start + state.frames.len * @sizeOf(usize);
    setShadowStackGuard(start, end);

    log(.Trace, "shadowstack.loadState({x})\n", state);
}

export fn TCShadowStackMismatch() noreturn {
    @panic("Shadow stack: Return target mismatch");
}

export fn TCShadowStackLogPush() void {
    markEvent(.ShadowPush);
}

export fn TCShadowStackLogAssertReturn() void {
    markEvent(.ShadowAssertReturn);
}

export fn TCShadowStackLogAssert() void {
    markEvent(.ShadowAssert);
}

// Non-Secure application interface
// ----------------------------------------------------------------------------

export fn __TCPrivateShadowPush() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
    );

    if (ENABLE_PROFILER) {
        asm volatile (
            \\ push {r0, r1, r2, r3, lr}
            \\ bl TCShadowStackLogPush
            \\ pop {r0, r1, r2, r3, lr}
        );
    }

    // r12 = continuation
    // lr = trustworthy return target of the caller with bit[0] cleared
    // kill: r12
    //
    //  assume(lr != 0);
    //  g_shadow_stack_top.* = lr;
    //  g_shadow_stack_top += 1;
    //
    asm volatile (
        \\ .syntax unified
        \\
        \\ ldr r5, .L_g_shadow_stack_top_const1 // Get &g_shadow_stack_top
        \\ ldr r4, [r5]                         // Get g_shadow_stack_top
        \\ bic r12, #1                          // Mark that `r12` is a Non-Secure address.
        \\ str lr, [r4], #4                     // g_shadow_stack_top[0] = lr, g_shadow_stack_top + 1
        \\ str r4, [r5]                         // g_shadow_stack_top = (g_shadow_stack_top + 1)
        \\
        \\ bxns r12
        \\
        \\ .align 2
        \\ .L_g_shadow_stack_top_const1: .word g_shadow_stack_top
    );
    unreachable;
}

export fn __TCPrivateShadowAssertReturn() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
    );

    if (ENABLE_PROFILER) {
        asm volatile (
            \\ push {r0, r1, r2, r3, lr}
            \\ bl TCShadowStackLogAssertReturn
            \\ pop {r0, r1, r2, r3, lr}
        );
    }

    // lr = non-trustworthy return target of the caller with bit[0] cleared
    // kill: r12
    if (comptime ABORTING_SHADOWSTACK) {
        //  if (g_shadow_stack_top[-1] != lr) { panic(); }
        //  g_shadow_stack_top -= 1;
        //  bxns(lr)
        //
        asm volatile (
            \\ .syntax unified
            \\
            \\ push {r0, r1}
            \\ ldr r12, .L_g_shadow_stack_top_const2 // Get &g_shadow_stack_top
            \\ ldr r0, [r12]                         // Get g_shadow_stack_top
            \\ ldr r1, [r0, #-4]!                    // g_shadow_stack_top - 1, Load g_shadow_stack_top[-1]
            \\ str r0, [r12]                         // g_shadow_stack_top = (g_shadow_stack_top - 1)
            \\ cmp r1, lr                            // g_shadow_stack_top[-1] != lr
            \\ pop {r0, r1}
            \\ bne .L_mismatch_trampoline            // if (g_shadow_stack_top[-1] != lr) { ... }
            \\
            \\ bxns lr
            \\
            \\ .align 2
            \\ .L_mismatch_trampoline: b TCShadowStackMismatch
            \\ .L_g_shadow_stack_top_const2: .word g_shadow_stack_top
        );
    } else { // ABORTING_SHADOWSTACK
        //
        //  lr = g_shadow_stack_top[-1];
        //  g_shadow_stack_top -= 1;
        //  bxns(lr)
        //
        asm volatile (
            \\ .syntax unified
            \\
            \\ push {r0}
            \\ ldr r12, .L_g_shadow_stack_top_const2 // Get &g_shadow_stack_top
            \\ ldr r0, [r12]                         // Get g_shadow_stack_top
            \\ ldr lr, [r0, #-4]!                    // g_shadow_stack_top - 1, load g_shadow_stack_top[-1]
            \\ str r0, [r12]                         // g_shadow_stack_top = (g_shadow_stack_top - 1)
            \\ pop {r0}
            \\
            \\ bxns lr
            \\
            \\ .align 2
            \\ .L_g_shadow_stack_top_const2: .word g_shadow_stack_top
        );
    } // ABORTING_SHADOWSTACK
    unreachable;
}

export fn __TCPrivateShadowAssertReturnFast() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
    );

    if (ENABLE_PROFILER) {
        asm volatile (
            \\ push {r0, r1, r2, r3, lr}
            \\ bl TCShadowStackLogAssertReturn
            \\ pop {r0, r1, r2, r3, lr}
        );
    }

    // Exactly the same as `__TCPrivateShadowAssertReturn` except that additional registers
    // are killed.

    // lr = non-trustworthy return target of the caller with bit[0] cleared
    // kill: r12
    if (comptime ABORTING_SHADOWSTACK) {
        //  [kill: r2, r3]
        //  if (g_shadow_stack_top[-1] != lr) { panic(); }
        //  g_shadow_stack_top -= 1;
        //  bxns(lr)
        //
        asm volatile (
            \\ .syntax unified
            \\
            \\ ldr r12, .L_g_shadow_stack_top_const5 // Get &g_shadow_stack_top
            \\ ldr r2, [r12]                         // Get g_shadow_stack_top
            \\ ldr r3, [r2, #-4]!                    // g_shadow_stack_top - 1, Load g_shadow_stack_top[-1]
            \\ str r2, [r12]                         // g_shadow_stack_top = (g_shadow_stack_top - 1)
            \\ cmp r3, lr                            // g_shadow_stack_top[-1] != lr
            \\ bne .L_mismatch_trampoline2           // if (g_shadow_stack_top[-1] != lr) { ... }
            \\
            \\ bxns lr
            \\
            \\ .align 2
            \\ .L_mismatch_trampoline2: b TCShadowStackMismatch
            \\ .L_g_shadow_stack_top_const5: .word g_shadow_stack_top
        );
    } else { // ABORTING_SHADOWSTACK
        //
        //  [kill: r3]
        //  lr = g_shadow_stack_top[-1];
        //  g_shadow_stack_top -= 1;
        //  bxns(lr)
        //
        asm volatile (
            \\ .syntax unified
            \\
            \\ ldr r12, .L_g_shadow_stack_top_const4 // Get &g_shadow_stack_top
            \\ ldr r3, [r12]                         // Get g_shadow_stack_top
            \\ ldr lr, [r3, #-4]!                    // g_shadow_stack_top - 1, load g_shadow_stack_top[-1]
            \\ str r3, [r12]                         // g_shadow_stack_top = (g_shadow_stack_top - 1)
            \\
            \\ bxns lr
            \\
            \\ .align 2
            \\ .L_g_shadow_stack_top_const4: .word g_shadow_stack_top
        );
    } // ABORTING_SHADOWSTACK
    unreachable;
}

export fn __TCPrivateShadowAssert() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
    );

    if (ENABLE_PROFILER) {
        asm volatile (
            \\ push {r0, r1, r2, r3, lr}
            \\ bl TCShadowStackLogAssert
            \\ pop {r0, r1, r2, r3, lr}
        );
    }

    // r12 = continuation
    // lr = non-trustworthy return target of the caller with bit[0] cleared
    // kill: r12
    if (comptime ABORTING_SHADOWSTACK) {
        //  if (g_shadow_stack_top[-1] != lr) { panic(); }
        //  g_shadow_stack_top -= 1;
        //  bxns(r12)
        //
        asm volatile (
            \\ .syntax unified
            \\
            \\ push {r0, r1, r2}
            \\ ldr r2, .L_g_shadow_stack_top_const3 // Get &g_shadow_stack_top
            \\ bic r12, #1                          // Mark that `r12` is a Non-Secure address.
            \\ ldr r0, [r2]                         // Get g_shadow_stack_top
            \\ ldr r1, [r0, #-4]!                   // g_shadow_stack_top - 1, Load g_shadow_stack_top[-1]
            \\ str r0, [r2]                         // g_shadow_stack_top = (g_shadow_stack_top - 1)
            \\ cmp r1, lr                           // g_shadow_stack_top[-1] != lr
            \\ pop {r0, r1, r2}
            \\ bne .L_mismatch_trampoline3          // if (g_shadow_stack_top[-1] != lr) { ... }
            \\
            \\ // Calling a secure gateway automatically clears LR[0]. It's useful
            \\ // for doing `bxns lr` in Secure code, but when used in Non-Secure
            \\ // mode, it just causes SecureFault.
            \\ orr lr, #1
            \\
            \\ bxns r12
            \\
            \\ .align 2
            \\ .L_mismatch_trampoline3: b TCShadowStackMismatch
            \\ .L_g_shadow_stack_top_const3: .word g_shadow_stack_top
        );
    } else { // ABORTING_SHADOWSTACK
        //
        //  lr = g_shadow_stack_top[-1];
        //  g_shadow_stack_top -= 1;
        //  bxns(r12)
        //
        asm volatile (
            \\ .syntax unified
            \\
            \\ push {r0, r2}
            \\ ldr r2, .L_g_shadow_stack_top_const3 // Get &g_shadow_stack_top
            \\ bic r12, #1                          // Mark that `r12` is a Non-Secure address.
            \\ ldr r0, [r2]                         // Get g_shadow_stack_top
            \\ ldr lr, [r0, #-4]!                   // g_shadow_stack_top - 1, load g_shadow_stack_top[-1]
            \\ str r0, [r2]                         // g_shadow_stack_top = (g_shadow_stack_top - 1)
            \\ pop {r0, r2}
            \\
            \\ // Calling a secure gateway automatically clears LR[0]. It's useful
            \\ // for doing `bxns lr` in Secure code, but when used in Non-Secure
            \\ // mode, it just causes SecureFault.
            \\ orr lr, #1
            \\
            \\ bxns r12
            \\
            \\ .align 2
            \\ .L_g_shadow_stack_top_const3: .word g_shadow_stack_top
        );
    } // ABORTING_SHADOWSTACK
    unreachable;
}

// Export the gateway functions to Non-Secure
comptime {
    @export(__TCPrivateShadowPush, .{ .name = "__acle_se___TCPrivateShadowPush", .linkage = .Strong, .section = ".gnu.sgstubs" });
    @export(__TCPrivateShadowAssertReturn, .{ .name = "__acle_se___TCPrivateShadowAssertReturn", .linkage = .Strong, .section = ".gnu.sgstubs" });
    @export(__TCPrivateShadowAssertReturnFast, .{ .name = "__acle_se___TCPrivateShadowAssertReturnFast", .linkage = .Strong, .section = ".gnu.sgstubs" });
    @export(__TCPrivateShadowAssert, .{ .name = "__acle_se___TCPrivateShadowAssert", .linkage = .Strong, .section = ".gnu.sgstubs" });
}
