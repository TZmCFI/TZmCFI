// The monitor part of the shadow exception stack implementation.
const arm_cmse = @import("../drivers/arm_cmse.zig");

const arm_m = @import("../drivers/arm_m.zig");
const EXC_RETURN = arm_m.EXC_RETURN;

const constants = @import("../constants.zig");
const VEC_TABLE = constants.VEC_TABLE;
const reverse = @import("utils.zig").reverse;

/// A copy of a portion of an exception frame.
const Frame = struct {
    /// The saved (original) program counter.
    pc: usize = 0,

    /// The saved (original) value of the LR register.
    lr: usize = 0,

    /// The `EXC_RETURN` value of the corresponding exception activation.
    exc_return: usize = 0,

    /// The original location of the exception frame.
    frame: usize = 0,

    const Self = @This();

    fn eq(self: Self, rhs: Self) bool {
        return self.pc == rhs.pc and
            self.lr == rhs.lr and
            self.exc_return == rhs.exc_return and
            self.frame == rhs.frame;
    }
};

/// Models a set of program counter values which are recognized as exception
/// entry.
const ExecptionEntryPCSet = struct {
    start: usize = 0,
    len: usize = 0,

    const Self = @This();

    fn setFromVtor(self: *Self, vtor: usize) void {
        // Validate the Non-Secure pointer
        const hdr = arm_cmse.checkSlice(usize, vtor, 2, arm_cmse.CheckOptions{}) catch |err| {
            @panic("The Non-Secure exception vector table's location is invalid.");
        };

        // Get the number of entries (including the header)
        var size = hdr[0];
        if ((size & VEC_TABLE.HDR_SIGNATURE_MASK) != VEC_TABLE.HDR_SIGNATURE) {
            @panic("TZmCFI magic number was not found in the Non-Secure exception vector table.");
        }
        size &= VEC_TABLE.HDR_SIZE_MASK;

        if (size < 2) {
            @panic("The Non-Secure exception vector table is too small.");
        } else if (size > 256) {
            @panic("The Non-Secure exception vector table is too large.");
        }

        if (size == 2) {
            self.len = 0;
            return;
        }

        // Find the rest of entries
        const entries = arm_cmse.checkSlice(usize, vtor, size, arm_cmse.CheckOptions{}) catch |err| {
            @panic("The Non-Secure exception vector table's location is invalid.");
        };

        const start = entries[2];
        if ((start & 1) == 0) {
            @panic("The address of an exception trampoline is malformed.");
        }

        var i: usize = 2;
        while (i < size) : (i += 1) {
            if (entries[i] != start + (i - 2) * VEC_TABLE.TRAMPOLINE_STRIDE) {
                @panic("Some exception trampolines are not layouted as expected.");
            }
        }

        self.start = start & ~usize(1);
        self.len = (size - 2) * VEC_TABLE.TRAMPOLINE_STRIDE;
    }

    fn contains(self: *const Self, pc: usize) bool {
        const rel = pc -% self.start;
        return pc < self.len and pc % VEC_TABLE.TRAMPOLINE_STRIDE == 0;
    }
};

var g_exception_entry_pc_set = ExecptionEntryPCSet{};

/// Iterates through the chained exception stack.
const ChainedExceptionStackIterator = struct {
    msp: usize,
    psp: usize,
    exc_return: usize,
    frame: [*]const usize,

    const Self = @This();

    /// Start iteration.
    fn new(exc_return: usize, msp: usize, psp: usize) Self {
        var self = Self{
            .msp = msp,
            .psp = psp,
            .exc_return = exc_return,
            .frame = undefined,
        };
        self.fillFrameAddress();
        return self;
    }

    fn fillFrameAddress(self: *Self) void {
        if ((self.exc_return & EXC_RETURN.SPSEL) != 0) {
            self.frame = @intToPtr([*]const usize, self.psp);
        } else {
            self.frame = @intToPtr([*]const usize, self.msp);
        }
    }

    fn getOriginalPc(self: *const Self) usize {
        return self.frame[6];
    }
    fn getOriginalLr(self: *const Self) usize {
        return self.frame[5];
    }
    fn getFrameAddress(self: *const Self) usize {
        return @ptrToInt(self.frame);
    }
    fn getExcReturn(self: *const Self) usize {
        return self.exc_return;
    }

    fn asFrame(self: *const Self) Frame {
        return Frame{
            .pc = self.getOriginalPc(),
            .lr = self.getOriginalLr(),
            .frame = self.getFrameAddress(),
            .exc_return = self.getExcReturn(),
        };
    }

    /// Moves to the next stack entry. Returns `false` if we can't proceed due
    /// to one of the following reasons:
    ///  - We reached the end of the chained exception stack.
    ///  - We reached the end of the exception stack.
    fn moveNext(self: *Self) bool {
        if ((self.exc_return & EXC_RETURN.MODE) != 0) {
            // Reached the end of the exception stack.
            return false;
        }

        if (!g_exception_entry_pc_set.contains(self.getOriginalPc())) {
            // The background context is an exception activation that already
            // started running software code. Thus we reached the end of the
            // chained exception stack.
            // (Even if we go on, we wouldn't be able to retrieve the rest of
            // the exception stack because we can't locate exception frames
            // without doing DWARF CFI-based stack unwinding.)
            return false;
        }

        const new_exc_return = self.getOriginalLr();

        // Unwind the stack
        const frameSize = if ((self.exc_return & EXC_RETURN.FTYPE) != 0) usize(32) else usize(104);
        if ((self.exc_return & EXC_RETURN.SPSEL) != 0) {
            self.psp += frameSize;
        } else {
            self.msp += frameSize;
        }

        self.exc_return = new_exc_return;
        self.fillFrameAddress();

        return true;
    }
};

/// The default shadow stack
var g_default_stack_storage: [32]Frame = undefined;

/// Bundles the state of a single instance of shadow exception stack.
const StackState = struct {
    current: [*]Frame,
    top: [*]Frame,
    limit: [*]Frame,

    const Self = @This();

    fn fromSlice(frames: []Frame) Self {
        var start = @ptrCast([*]Frame, &frames[0]);
        return Self{
            .current = start,
            .top = start,
            .limit = start + frames.len,
        };
    }
};

// TODO: Static initialize
var g_stack: StackState = undefined;

/// Perform the shadow push operation.
fn pushShadowExcStack(exc_return: usize, msp: usize, psp: usize) void {
    var exc_stack = ChainedExceptionStackIterator.new(exc_return, msp, psp);

    const stack = &g_stack;
    var new_top: [*]Frame = stack.top;

    // TODO: Add bounds check using `StackState::limit`

    if (new_top == stack.current) {
        // The shadow exception stack is empty -- push every frame we find
        while (true) {
            new_top.* = exc_stack.asFrame();
            new_top += 1;

            if (!exc_stack.moveNext()) {
                break;
            }
        }
    } else {
        // Push until a known entry is encountered
        const top_frame = (new_top - 1).*.frame;

        while (true) {
            if (exc_stack.getFrameAddress() == top_frame) {
                break;
            }

            new_top.* = exc_stack.asFrame();
            new_top += 1;

            if (!exc_stack.moveNext()) {
                break;
            }
        }
    }

    // The entries were inserted in a reverse order. Reverse them to be in the
    // correct order.
    reverse(Frame, stack.top, new_top);

    stack.top = new_top;
}

/// Perform the shadow pop (assert) opertion and get the `EXC_RETURN` that
/// corresponds to the current exception activation.
fn popShadowExcStack(msp: usize, psp: usize) usize {
    const stack = &g_stack;

    if (stack.top == stack.current) {
        @panic("Exception return trampoline was called but the shadow exception stack is empty.");
    }

    const exc_return = (stack.top - 1)[0].exc_return;

    var exc_stack = ChainedExceptionStackIterator.new(exc_return, msp, psp);

    // Validate *two* top entries.
    if (!exc_stack.asFrame().eq((stack.top - 1)[0])) {
        @panic("Exception stack integrity check has failed.");
    }
    if (exc_stack.moveNext()) {
        if (stack.top == stack.current + 1) {
            @panic("The number of entries in the shadow exception stack is lower than expected.");
        }
        if (!exc_stack.asFrame().eq((stack.top - 2)[0])) {
            @panic("Exception stack integrity check has failed.");
        }
    }

    stack.top -= 1;

    return exc_return;
}

const Usizex2 = @Vector(2, usize);

export fn __tcEnterInterrupt(isr_body: usize, exc_return: usize, msp: usize, psp: usize) Usizex2 {
    pushShadowExcStack(exc_return, msp, psp);

    // TODO: Conceal `r3` and `r4`?
    var ret = [2]usize{ exc_return, isr_body };
    return @bitCast(Usizex2, ret);
}

export fn __tcLeaveInterrupt(msp: usize, psp: usize) usize {
    return popShadowExcStack(msp, psp);
}

// Non-Secure application interface
// ----------------------------------------------------------------------------

/// Implements a secure function in `Secure.h`.
pub export fn TCInitialize(ns_vtor: usize) void {
    g_stack = StackState.fromSlice(&g_default_stack_storage);
    g_exception_entry_pc_set.setFromVtor(ns_vtor);
}

/// Implements a private gateway function in `PrivateGateway.h`.
pub export nakedcc fn __TCPrivateEnterInterrupt() linksection(".gnu.sgstubs") noreturn {
    // This `asm` block provably never returns
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
        \\
        \\ # r0 = handler function pointer
        \\ mov r1, lr
        \\ mrs r2, msp_ns
        \\ mrs r3, psp_ns
        \\
        \\ bl __tcEnterInterrupt
        \\
        \\ # r0 = lr (EXC_RETURN)
        \\ # r1 = handler function pointer
        \\
        \\ adr lr, __TCPrivateLeaveInterrupt
        \\ bxns r1
    );
    unreachable;
}

/// Implements a private gateway function in `PrivateGateway.h`.
pub export nakedcc fn __TCPrivateLeaveInterrupt() linksection(".gnu.sgstubs") noreturn {
    // This `asm` block provably never returns
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
        \\
        \\ mrs r0, msp_ns
        \\ mrs r1, psp_ns
        \\
        \\ bl __tcLeaveInterrupt
        \\
        \\ # r0 = EXC_RETURN
        \\
        \\ bx r0
    );
    unreachable;
}
