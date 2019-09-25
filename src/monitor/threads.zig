// Thread management
// ----------------------------------------------------------------------------
const std = @import("std");
const FixedBufferAllocator = std.heap.FixedBufferAllocator;
// ----------------------------------------------------------------------------
const arm_m = @import("../drivers/arm_m.zig");
const arm_cmse = @import("../drivers/arm_cmse.zig");
// ----------------------------------------------------------------------------
const shadowexcstack = @import("shadowexcstack.zig");
const ffi = @import("ffi.zig");

const warn = @import("debug.zig").warn;
// ----------------------------------------------------------------------------

// TODO: Critical section
//       We currently put a trust on the Non-Secure code calling these functions
//       in a way that it does not cause data race. We assume the Non-Secure
//       code is protected by TZmCFI in a way we intended. For example,
//       `TCCreateThread` is called only by the initialization code, outside any
//       exception handlers, and `TCActivateThread` is called only by a PendSV
//       handler, which is configured with the lowest priority. When it's
//       violated (e.g., because of a rogue Non-Secure developer or compromised
//       firmware upgrade process), well, that means the Secure code is compro-
//       mised.

var arena: [8192]u8 = undefined;
var fixed_allocator: FixedBufferAllocator = undefined;
const allocator = &fixed_allocator.allocator;

const NonSecureThread = struct {
    exc_stack_state: shadowexcstack.StackState,
};

var threads = [1]?*NonSecureThread{null} ** 64;
var next_free_thread: u8 = undefined;
var cur_thread: u8 = 0;

var default_thread: NonSecureThread = undefined;

pub fn init() void {
    fixed_allocator = FixedBufferAllocator.init(&arena);
    for (threads) |*thread| {
        thread.* = null;
    }
    next_free_thread = 1;

    // Default thread
    cur_thread = 0;
    threads[0] = &default_thread;
}

const CreateThreadError = error{OutOfMemory};

fn createThread(create_info: *const ffi.TCThreadCreateInfo) CreateThreadError!ffi.TCThread {
    if (usize(next_free_thread) >= threads.len) {
        return error.OutOfMemory;
    }

    const thread_id = usize(next_free_thread);

    const thread_info = try allocator.create(NonSecureThread);
    errdefer allocator.destroy(thread_info);

    const exc_stack_state = try shadowexcstack.StackState.new(allocator, create_info);
    errdefer exc_stack_state.destroy(allocator);

    thread_info.exc_stack_state = exc_stack_state;

    // Commit the update
    next_free_thread += 1;
    threads[thread_id] = thread_info;

    warn("createThread({}) = {}\r\n", create_info, thread_id);

    return thread_id;
}

const ActivateThreadError = error{
    BadThread,
    ThreadMode,
};

fn activateThread(thread: ffi.TCThread) ActivateThreadError!void {
    // Cannot switch contexts in Thread mode. We cannot switch secure process
    // stacks while they are in use, not to mention that switching contexts
    // in Thread mode is a weird thing to do.
    if (!arm_m.isHandlerMode()) {
        return error.ThreadMode;
    }

    // This is probably faster than proper bounds checking
    const new_thread_id = usize(thread) & (threads.len - 1);
    const new_thread = threads[new_thread_id] orelse return error.BadThread;

    const old_thread_id = usize(cur_thread);
    const old_thread = threads[old_thread_id].?;

    warn("activateThread({} → {})\r\n", old_thread_id, new_thread_id);

    shadowexcstack.saveState(&old_thread.exc_stack_state);
    shadowexcstack.loadState(&new_thread.exc_stack_state);

    cur_thread = @truncate(u8, new_thread_id);
}

// Non-Secure application interface
// ----------------------------------------------------------------------------

extern fn TCReset(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    init();
    return 0;
}

extern fn TCCreateThread(raw_p_create_info: usize, raw_p_thread: usize, _3: usize, _4: usize) usize {
    // Check Non-Secure pointers
    const p_create_info = arm_cmse.checkObject(ffi.TCThreadCreateInfo, raw_p_create_info, arm_cmse.CheckOptions{}) catch |err| {
        return @enumToInt(ffi.TC_RESULT.ERROR_UNPRIVILEGED);
    };

    const p_thread = arm_cmse.checkObject(ffi.TCThread, raw_p_thread, arm_cmse.CheckOptions{ .readwrite = true }) catch |err| {
        return @enumToInt(ffi.TC_RESULT.ERROR_UNPRIVILEGED);
    };

    const create_info = p_create_info.*;
    const thread = createThread(&create_info) catch |err| switch (err) {
        error.OutOfMemory => return @enumToInt(ffi.TC_RESULT.ERROR_OUT_OF_MEMORY),
    };

    p_thread.* = thread;

    return @enumToInt(ffi.TC_RESULT.SUCCESS);
}

extern fn TCLockdown(_1: usize, _2: usize, _3: usize, _4: usize) usize {
    @panic("unimplemented");
}

extern fn TCActivateThread(thread: usize, _2: usize, _3: usize, _4: usize) usize {
    activateThread(thread) catch |err| switch (err) {
        error.BadThread => return @enumToInt(ffi.TC_RESULT.ERROR_INVALID_ARGUMENT),
        error.ThreadMode => return @enumToInt(ffi.TC_RESULT.ERROR_INVALID_OPERATION),
    };

    return @enumToInt(ffi.TC_RESULT.SUCCESS);
}

comptime {
    arm_cmse.exportNonSecureCallable("TCReset", TCReset);
    arm_cmse.exportNonSecureCallable("TCCreateThread", TCCreateThread);
    arm_cmse.exportNonSecureCallable("TCLockdown", TCLockdown);
    arm_cmse.exportNonSecureCallable("TCActivateThread", TCActivateThread);
}
