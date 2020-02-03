// ----------------------------------------------------------------------------
const std = @import("std");
// ----------------------------------------------------------------------------
const arm_cmse = @import("arm_cmse");
const arm_m = @import("arm_m");
pub const port = @import("../ports/" ++ @import("build_options").BOARD ++ "/secure.zig");
const secure_board_vec_table = @import("../ports/" ++ @import("build_options").BOARD ++ "/excvector.zig").secure_board_vec_table;
// ----------------------------------------------------------------------------
// Import definitions in `monitor.zig`, which is compiled as a separate
// compilation unit
const monitor = @import("../monitor/exports.zig");
// ----------------------------------------------------------------------------

export fn main() void {
    // Enable SecureFault, UsageFault, BusFault, and MemManage for ease of
    // debugging. (Without this, they all escalate to HardFault)
    arm_m.scb.regShcsr().* =
        arm_m.Scb.SHCSR_MEMFAULTENA |
        arm_m.Scb.SHCSR_BUSFAULTENA |
        arm_m.Scb.SHCSR_USGFAULTENA |
        arm_m.Scb.SHCSR_SECUREFAULTENA;

    // Enable Non-Secure BusFault, HardFault, and NMI.
    // Prioritize Secure exceptions.
    arm_m.scb.regAircr().* =
        (arm_m.scb.regAircr().* & ~arm_m.Scb.AIRCR_VECTKEY_MASK) |
        arm_m.Scb.AIRCR_BFHFNMINS | arm_m.Scb.AIRCR_PRIS |
        arm_m.Scb.AIRCR_VECTKEY_MAGIC;

    // Intialize secure stacks
    // -----------------------------------------------------------------------
    // On reset, MSP is used for both of Thread and Handler modes. We want to
    // set a new stack pointer only for Handler mode by updating MSP, but MSP
    // is currently in use. So, we first copy MSP To PSP and then switch to
    // PSP.
    asm volatile (
        \\ mrs r0, msp
        \\ msr psp, r0
        \\ mrs r0, control
        \\ orr r0, #2       // SPSEL = 1 (Use PSP in Thread mode)
        \\ msr control, r0
        :
        :
        : "r0"
    );

    // Now we can safely update MSP.
    arm_m.setMsp(@ptrToInt(_handler_stack_top));

    // Set stack limits.
    arm_m.setMspLimit(@ptrToInt(_handler_stack_limit));
    arm_m.setPspLimit(@ptrToInt(_main_stack_limit));

    // Board-specific initialization
    // -----------------------------------------------------------------------
    port.init();

    port.print("(Hit ^A X to quit QEMU)\r\n", .{});
    port.print("The Secure code is running!\r\n", .{});

    // Enable SAU
    // -----------------------------------------------------------------------
    arm_cmse.sau.regCtrl().* |= arm_cmse.Sau.CTRL_ENABLE;

    // Initialize Secure MPU
    // -----------------------------------------------------------------------
    // TZmCFI Shadow Stack utilizes MPU for bound checking.
    const mpu = arm_m.mpu;
    const Mpu = arm_m.Mpu;
    //  - `CTRL_HFNMIENA`: Keep MPU on even if the current execution priority
    //    is less than 0 (e.g., in a HardFault handler and when `FAULTMASK` is
    //    set to 1).
    //
    //  - `CTRL_PRIVDEFENA`: Allow privileged access everywhere as if MPU
    //    is not enabled. Region overlaps still cause access violation, which
    //    we utilize for the bound checking.
    //
    mpu.regCtrl().* = Mpu.CTRL_ENABLE | Mpu.CTRL_HFNMIENA | Mpu.CTRL_PRIVDEFENA;

    // The region 2
    mpu.regRnr().* = 0;
    mpu.regRbarA(2).* = 0 | Mpu.RBAR_AP_RW_ANY;
    mpu.regRlarA(2).* = Mpu.RLAR_LIMIT_MASK | Mpu.RLAR_EN;

    // Initialize TZmCFI Monitor
    // -----------------------------------------------------------------------
    // Call `TCXInitializeMonitor` that resides in a different
    // compilation unit
    monitor.TCXInitializeMonitor(tcWarnHandler);

    // Boot the Non-Secure code
    // -----------------------------------------------------------------------
    // Configure the Non-Secure exception vector table
    arm_m.scb_ns.regVtor().* = port.VTOR_NS;

    port.print("Booting the Non-Secure code...\r\n", .{});

    // Call Non-Secure code's entry point
    const ns_entry = @intToPtr(*volatile fn () void, port.VTOR_NS + 4).*;
    _ = arm_cmse.nonSecureCall(ns_entry, 0, 0, 0, 0);

    @panic("Non-Secure reset handler returned unexpectedly");
}

fn tcWarnHandler(data: [*]const u8, len: usize) callconv(.C) void {
    port.print("{}", .{data[0..len]});
}

// ----------------------------------------------------------------------------

/// The Non-Secure-callable function that outputs zero or more bytes to the
/// debug output.
fn nsDebugOutput(count: usize, ptr: usize, r2: usize, r32: usize) callconv(.C) usize {
    const bytes = arm_cmse.checkSlice(u8, ptr, count, arm_cmse.CheckOptions{}) catch |err| {
        port.print("warning: pointer security check failed: {}\r\n", .{err});
        port.print("         count = {}, ptr = 0x{x}\r\n", .{ count, ptr });
        return 0;
    };

    // Even if the permission check has succeeded, it's still unsafe to treat
    // Non-Secure pointers as normal pointers (this is why `bytes` is
    // `[]volatile u8`), so we can't use `writeSlice` here.
    for (bytes) |byte| {
        port.printByte(byte);
    }

    return 0;
}

comptime {
    arm_cmse.exportNonSecureCallable("debugOutput", nsDebugOutput);
}

// ----------------------------------------------------------------------------
// Build the exception vector table
// zig fmt: off
const VecTable = @import("../common/vectable.zig").VecTable;
export const exception_vectors linksection(".isr_vector") = secure_board_vec_table
    .setInitStackPtr(_main_stack_top)
    .setExcHandler(arm_m.irqs.Reset_IRQn, handleReset);
// zig fmt: on
extern fn _main_stack_top() void;
extern fn _handler_stack_top() void;
extern fn _main_stack_limit() void;
extern fn _handler_stack_limit() void;
extern fn handleReset() void;
