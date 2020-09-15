const arm_m = @import("arm_m");
const eql = @import("std").mem.eql;
const scb = arm_m.scb;

const SHADOW_EXC_STACK_TYPE = @import("build_options").SHADOW_EXC_STACK_TYPE;

const no_nested_exceptions = eql(u8, SHADOW_EXC_STACK_TYPE, "Unnested") or eql(u8, SHADOW_EXC_STACK_TYPE, "Null");

pub fn disableNestedExceptionIfDisallowed() void {
    if (no_nested_exceptions) {
        // Allocate all bits for subpriority, no bits for group priority.
        // Only HardFault is allowed to preempt another exception.
        scb.setPriorityGrouping(7);
    }
}
