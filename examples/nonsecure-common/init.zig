const arm_m = @import("arm_m");
const scb = arm_m.scb;

const NO_NESTED_EXCEPTIONS = @import("build_options").NO_NESTED_EXCEPTIONS;

pub fn disableNestedExceptionIfDisallowed() void {
    if (NO_NESTED_EXCEPTIONS) {
        // Allocate all bits for subpriority, no bits for group priority.
        // Only HardFault is allowed to preempt another exception.
        scb.setPriorityGrouping(7);
    }
}
