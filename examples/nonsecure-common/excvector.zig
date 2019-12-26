const arm_m = @import("arm_m");

// zig fmt: off

const VecTable = @import("../ports/" ++ @import("build_options").BOARD ++ "/excvector.zig").BoardVecTable;

// Compiler bug: If you use write `pub const default_baremetal = ...` instead and
//               try to export it in a different name by writing like
//               `export const other_name = default_baremetal;`, the compiler generates
//               a symbol with the original name (`default_baremetal`) anyway.

pub fn getDefaultBaremetal() VecTable {
    return VecTable
        .new()
        .setInitStackPtr(_main_stack_top)
        .setExcHandler(arm_m.irqs.Reset_IRQn, handleReset);
}

pub fn getDefaultFreertos() VecTable {
    return getDefaultBaremetal()
        .setExcHandler(arm_m.irqs.SvCall_IRQn, SVC_Handler)
        .setExcHandler(arm_m.irqs.PendSv_IRQn, PendSV_Handler)
        .setExcHandler(arm_m.irqs.SysTick_IRQn, SysTick_Handler);
}

// zig fmt: on

extern fn _main_stack_top() void;
extern fn handleReset() void;

// These are a part of FreeRTOS
extern fn SysTick_Handler() void;
extern fn PendSV_Handler() void;
extern fn SVC_Handler() void;
