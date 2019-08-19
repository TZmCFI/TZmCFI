
export const exception_vectors linksection(".isr_vector") = [_]extern fn () void{
    _main_stack_top,
    handleReset,
    unhandled("NMI"), // NMI
    unhandled("HardFault"), // HardFault
    unhandled("MemManage"), // MemManage
    unhandled("BusFault"), // BusFault
    unhandled("UsageFault"), // UsageFault
    unhandled("SecureFault"), // SecureFault
    unhandled("Reserved 1"), // Reserved 1
    unhandled("Reserved 2"), // Reserved 2
    unhandled("Reserved 3"), // Reserved 3
    SVC_Handler, // SVCall
    unhandled("DebugMonitor"), // DebugMonitor
    unhandled("Reserved 4"), // Reserved 4
    PendSV_Handler, // PendSV
    SysTick_Handler, // SysTick
    unhandled("External interrupt 0"), // External interrupt 0
};

/// Not a function, actually, but suppresses type error
extern fn _main_stack_top() void;

/// But this is really a function!
extern fn handleReset() void;

// These are a part of FreeRTOS
extern fn SysTick_Handler() void;
extern fn PendSV_Handler() void;
extern fn SVC_Handler() void;

/// Create an "unhandled exception" handler.
fn unhandled(comptime name: []const u8) extern fn () void {
    const ns = struct {
        extern fn handler() void {
            @panic("unhandled exception: " ++ name);
        }
    };
    return ns.handler;
}
