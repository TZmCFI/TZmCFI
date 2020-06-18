// The monitor part of the shadow exception stack implementation.
// ----------------------------------------------------------------------------
const builtin = @import("builtin");

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const rotr = std.math.rotr;
// ----------------------------------------------------------------------------
const arm_cmse = @import("../drivers/arm_cmse.zig");

const arm_m = @import("../drivers/arm_m.zig");
const EXC_RETURN = arm_m.EXC_RETURN;
const getMspNs = arm_m.getMspNs;
const getPspNs = arm_m.getPspNs;
// ----------------------------------------------------------------------------
const constants = @import("../constants.zig");
const VEC_TABLE = constants.VEC_TABLE;
const reverse = @import("utils.zig").reverse;

const threads = @import("threads.zig");

const TCThreadCreateInfo = @import("ffi.zig").TCThreadCreateInfo;

const log = @import("debug.zig").log;

const markEvent = @import("profiler.zig").markEvent;

const options = @import("options.zig");
const NO_NESTED_EXCEPTIONS = options.NO_NESTED_EXCEPTIONS;
// ----------------------------------------------------------------------------

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

    /// The saved R12 (IP). This register is used to store code pointers in
    /// our shadow stack implementation.
    r12: usize = 0,

    const Self = @This();

    fn eq(self: Self, rhs: Self) bool {
        return self.pc == rhs.pc and
            self.lr == rhs.lr and
            self.exc_return == rhs.exc_return and
            self.frame == rhs.frame and
            self.r12 == rhs.r12;
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

        self.start = start & ~@as(usize, 1);
        self.len = size - 2;
    }

    fn contains(self: *const Self, pc: usize) bool {
        const rel = pc -% self.start;

        // return pc < (self.len << stride_shift) and pc % VEC_TABLE.TRAMPOLINE_STRIDE == 0;

        // Use a bit rotation trick to do alignment and boundary checks
        // at the same time.
        return rotr(usize, rel, VEC_TABLE.TRAMPOLINE_STRIDE_SHIFT) < self.len;
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
        if ((self.exc_return & EXC_RETURN.S) != 0) {
            // `g_exception_entry_pc_set` only contains non-Secure exception
            // entries. Thus it's invalid for `getOriginalPc()` to be included
            // in `g_exception_entry_pc_set`. But we can't check that here;
            // `getOriginalPc` assumes the exception frame is in a non-Secure
            // stack.

            //   Assumption: For every exception entry chain A → B, A never
            //   belongs to Secure mode.
            //
            // This assumption makes things simpler. When a Non-Secure
            // exception takes in Secure mode, additional state context data is
            // pushed, changing the layout of an exception frame.
            // We think this use case is extremely rare, so we chose to assume
            // this never happens and not to introduce additional latency by
            // addressing this case.
            //
            // Since there are no more exception entry chains, the chained
            // exception stack ends here, so does unwinding. Still, we need an
            // exception frame for `asFrame` to read. Just use a dummy
            // exception frame here.
            self.frame = @ptrCast([*]const usize, &dummy_exc_frame[0]);
        } else if ((self.exc_return & EXC_RETURN.SPSEL) != 0) {
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
    fn getOriginalR12(self: *const Self) usize {
        return self.frame[4];
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
            .r12 = self.getOriginalR12(),
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

        // An execption context never uses PSP.
        assert((self.exc_return & EXC_RETURN.SPSEL) == 0);

        // Unwind the stack
        const frameSize = if ((self.exc_return & EXC_RETURN.FTYPE) != 0) @as(usize, 32) else @as(usize, 104);
        self.msp += frameSize;

        self.exc_return = new_exc_return;
        self.fillFrameAddress();

        return true;
    }
};

const dummy_exc_frame = [1]usize{0} ** 7;

// The default SES implementation supporting nested exceptions.
const nested_impl = struct {
    /// The default shadow stack
    var g_default_stack_storage: [32]Frame = undefined;

    /// Bundles the state of a single instance of shadow exception stack.
    const StackStateImpl = struct {
        current: [*]Frame,
        top: [*]Frame,
        limit: [*]Frame,

        const Self = @This();

        /// Construct a `StackStateImpl` by allocating memory from `allocator`.
        pub fn new(allocator: *Allocator, create_info: *const TCThreadCreateInfo) !Self {
            const frames = try allocator.alloc(Frame, 4);
            var self = fromSlice(frames);

            self.top[0] = Frame{
                .pc = create_info.initialPC,
                .lr = create_info.initialLR,
                .exc_return = create_info.excReturn,
                .frame = create_info.exceptionFrame,
                .r12 = 0x12121212,
            };
            self.top += 1;

            return self;
        }

        /// Release the memory allocated for `self`. `self` must have been created
        /// by `new(allocator, _)`.
        pub fn destroy(self: *const Self, allocator: *Allocator) void {
            allocator.free(self.asSlice());
        }

        fn fromSlice(frames: []Frame) Self {
            var start = @ptrCast([*]Frame, &frames[0]);
            return Self{
                .current = start,
                .top = start,
                .limit = start + frames.len,
            };
        }

        fn asSlice(self: *const Self) []Frame {
            const len = @divExact(@ptrToInt(self.limit) - @ptrToInt(self.current), @sizeOf(Frame));
            return self.current[0..len];
        }
    };

    fn createStackStateWithDefaultStorage() StackStateImpl {
        return StackStateImpl.fromSlice(&g_default_stack_storage);
    }

    /// Perform the shadow push operation.
    fn pushShadowExcStack(exc_return: usize) void {
        var exc_stack = ChainedExceptionStackIterator.new(exc_return, getMspNs(), getPspNs());

        const stack = &g_stack;
        var new_top: [*]Frame = stack.top;

        // TODO: Add bounds check using `StackStateImpl::limit`

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
    fn popShadowExcStack() usize {
        const stack = &g_stack;

        if (stack.top == stack.current) {
            @panic("Exception return trampoline was called but the shadow exception stack is empty.");
        }

        const exc_return = (stack.top - 1)[0].exc_return;

        var exc_stack = ChainedExceptionStackIterator.new(exc_return, getMspNs(), getPspNs());

        // Validate *two* top entries.
        if (!exc_stack.asFrame().eq((stack.top - 1)[0])) {
            log(.Warning, "popShadowExcStack: {} != {}\r\n", .{ exc_stack.asFrame(), (stack.top - 1)[0] });
            @panic("Exception stack integrity check has failed.");
        }
        if (exc_stack.moveNext()) {
            if (stack.top == stack.current + 1) {
                @panic("The number of entries in the shadow exception stack is lower than expected.");
            }
            if (!exc_stack.asFrame().eq((stack.top - 2)[0])) {
                log(.Warning, "popShadowExcStack: {} != {}\r\n", .{ exc_stack.asFrame(), (stack.top - 2)[0] });
                @panic("Exception stack integrity check has failed.");
            }
        }

        stack.top -= 1;

        return exc_return;
    }
};

// The simplified SES implementation not supporting nested exceptions.
const unnested_impl = struct {
    /// The default shadow stack
    var g_default_stack_storage: Frame = undefined;

    /// Bundles the state of a single instance of shadow exception stack.
    const StackStateImpl = struct {
        current: ?*Frame,
        storage: *Frame,

        const Self = @This();

        /// Construct a `StackStateImpl` by allocating memory from `allocator`.
        pub fn new(allocator: *Allocator, create_info: *const TCThreadCreateInfo) !Self {
            const storage = try allocator.create(Frame);
            var self = fromStorage(storage);

            storage.* = Frame{
                .pc = create_info.initialPC,
                .lr = create_info.initialLR,
                .exc_return = create_info.excReturn,
                .frame = create_info.exceptionFrame,
                .r12 = 0x12121212,
            };
            self.current = self.storage;

            return self;
        }

        /// Release the memory allocated for `self`. `self` must have been created
        /// by `new(allocator, _)`.
        pub fn destroy(self: *const Self, allocator: *Allocator) void {
            allocator.destroy(self.storage);
        }

        fn fromStorage(storage: *Frame) Self {
            return Self{
                .current = null,
                .storage = storage,
            };
        }
    };

    fn createStackStateWithDefaultStorage() StackStateImpl {
        return StackStateImpl.fromStorage(&g_default_stack_storage);
    }

    /// Perform the shadow push operation.
    fn pushShadowExcStack(exc_return: usize) void {
        const stack = &g_stack;

        var exc_stack = ChainedExceptionStackIterator.new(exc_return, getMspNs(), getPspNs());

        if (stack.current != null) {
            @panic("Shadow exception stack is already occupied.");
        }

        stack.current = stack.storage;
        stack.storage.* = exc_stack.asFrame();
    }

    /// Perform the shadow pop (assert) opertion and get the `EXC_RETURN` that
    /// corresponds to the current exception activation.
    fn popShadowExcStack() usize {
        const stack = &g_stack;

        const frame = stack.current orelse {
            @panic("Exception return trampoline was called but the shadow exception stack is empty.");
        };

        const exc_return = frame.exc_return;

        var exc_stack = ChainedExceptionStackIterator.new(exc_return, getMspNs(), getPspNs());

        // Validate the entry.
        if (!exc_stack.asFrame().eq(frame.*)) {
            log(.Warning, "popShadowExcStack: {} != {}\r\n", .{ exc_stack.asFrame(), frame });
            @panic("Exception stack integrity check has failed.");
        }

        stack.current = null;

        return exc_return;
    }
};

// Choose an implementation based on `NO_NESTED_EXCEPTIONS`
const impl = if (NO_NESTED_EXCEPTIONS) unnested_impl else nested_impl;
pub const StackState = impl.StackStateImpl;

// TODO: Static initialize
var g_stack: StackState = undefined;

const Usizex2 = @Vector(2, usize);

export fn __tcEnterInterrupt(isr_body: usize, exc_return: usize) Usizex2 {
    markEvent(.EnterInterrupt);

    impl.pushShadowExcStack(exc_return);

    // TODO: Conceal `r3` and `r4`?
    var ret = [2]usize{ exc_return, isr_body };
    return @bitCast(Usizex2, ret);
}

export fn __tcLeaveInterrupt() usize {
    markEvent(.LeaveInterrupt);

    return impl.popShadowExcStack();
}

pub fn saveState(state: *StackState) void {
    state.* = g_stack;
}

pub fn loadState(state: *const StackState) void {
    g_stack = state.*;
}

export fn __tcReportBadNesting() noreturn {
    @panic("Nested exception is disallowed.");
}

// Non-Secure application interface
// ----------------------------------------------------------------------------

/// Implements a secure function in `Secure.h`.
pub export fn TCInitialize(ns_vtor: usize) void {
    threads.init();

    g_stack = impl.createStackStateWithDefaultStorage();
    if (!NO_NESTED_EXCEPTIONS) {
        g_exception_entry_pc_set.setFromVtor(ns_vtor);
    }
}

/// Implements a private gateway function in `PrivateGateway.h`.
pub export fn __TCPrivateEnterInterrupt() callconv(.Naked) noreturn {
    // This `asm` block provably never returns
    @setRuntimeSafety(false);

    if (NO_NESTED_EXCEPTIONS) {
        asm volatile (
            \\ sg
            \\
            \\ # r0 = handler function pointer
            \\ mov r1, lr
            \\
            \\ # Deny nested exception by checking the Mode bit. A cleared Mode
            \\ # bit means the exception was taken in Handler mode.
            \\ tst lr, #8
            \\ beq __tcReportBadNesting
            \\
            \\ bl __tcEnterInterrupt
            \\
            \\ # r0 = lr (EXC_RETURN)
            \\ # r1 = handler function pointer
            \\
            \\ bxns r1
        );
    } else {
        asm volatile (
            \\ sg
            \\
            \\ # r0 = handler function pointer
            \\ mov r1, lr
            \\
            \\ bl __tcEnterInterrupt
            \\
            \\ # r0 = lr (EXC_RETURN)
            \\ # r1 = handler function pointer
            \\
            \\ bxns r1
        );
    }

    unreachable;
}

/// Implements a private gateway function in `PrivateGateway.h`.
pub export fn __TCPrivateLeaveInterrupt() callconv(.Naked) noreturn {
    // This `asm` block provably never returns
    @setRuntimeSafety(false);

    asm volatile (
        \\ sg
        \\
        \\ bl __tcLeaveInterrupt
        \\
        \\ # r0 = EXC_RETURN
        \\
        \\ bx r0
    );
    unreachable;
}

// Export the gateway functions to Non-Secure
comptime {
    @export(__TCPrivateEnterInterrupt, .{ .name = "__acle_se___TCPrivateEnterInterrupt", .linkage = .Strong, .section = ".gnu.sgstubs" });
    @export(__TCPrivateLeaveInterrupt, .{ .name = "__acle_se___TCPrivateLeaveInterrupt", .linkage = .Strong, .section = ".gnu.sgstubs" });
}
