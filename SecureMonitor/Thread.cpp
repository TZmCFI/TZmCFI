#include <array>

#include <TZmCFI/Gateway.h>

#include "Assert.hpp"
#include "Exception.hpp"
#include "LinearAllocator.hpp"
#include "Mutex.hpp"

// #define TZMCFI_TRACE 1

namespace TZmCFI {
namespace {

LinearAllocator<8192> g_arena;

struct NonSecureThread {
    ShadowExceptionStackState shadow_exc_stack;
};

std::array<NonSecureThread *, 64> g_threads;
std::uint8_t g_nextFreeThread = 0;
std::uint8_t g_activeThread = 0;

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

TCResult Reset() noexcept {
    g_arena.Reset();
    return TC_RESULT_SUCCESS;
}

TCResult CreateThread(const TCThreadCreateInfo &createInfo, TCThread &outThread,
                      bool isRunning) noexcept {
    if (g_nextFreeThread >= (std::uint8_t)g_threads.size()) {
        return TC_RESULT_ERROR_OUT_OF_MEMORY;
    }

    // Create a `NonSecureThread`
    // TODO: Relinquish memory on failure
    auto thread_alloc = g_arena.Allocate<NonSecureThread>();
    if (!thread_alloc) {
        return TC_RESULT_ERROR_OUT_OF_MEMORY;
    }

    NonSecureThread &thread = *thread_alloc->first;

    // Allocate a mmeory region for the shadow exception stack
    constexpr size_t shadow_exc_stack_size = 128;
    auto ses_storage = g_arena.AllocateBytes(shadow_exc_stack_size, 4);
    if (!ses_storage) {
        return TC_RESULT_ERROR_OUT_OF_MEMORY;
    }

    // Initialize the shadow exception stack
    thread.shadow_exc_stack.start = ses_storage->ptr;
    thread.shadow_exc_stack.limit = ses_storage->ptr + shadow_exc_stack_size;
    CreateShadowExceptionStackState(createInfo, thread.shadow_exc_stack, isRunning);

    // Allocate a thread ID
    outThread = static_cast<TCThread>(g_nextFreeThread);
    g_threads[g_nextFreeThread++] = &thread;

    return TC_RESULT_SUCCESS;
}

TCResult Lockdown() noexcept { Unimplemented(); }

TCResult ActivateThread(TCThread threadId) noexcept {
    // This is probably faster than proper bounds checking
    threadId &= static_cast<TCThread>(g_threads.size() - 1);

    // Check the validity of the thread ID
    if (!g_threads[threadId]) {
        return TC_RESULT_ERROR_INVALID_ARGUMENT;
    }

    // Save the currrently active thread's state
    {
        NonSecureThread &thread = *g_threads[g_activeThread];

        SaveShadowExceptionStackState(thread.shadow_exc_stack);
    }

    // Restore the new active thread's state
    {
        NonSecureThread &thread = *g_threads[threadId];

        LoadShadowExceptionStackState(thread.shadow_exc_stack);
    }
    g_activeThread = threadId;

    return TC_RESULT_SUCCESS;
}

}; // namespace

void InitializeDefaultThread() {
    TCResult result;
    // Most of the fields are unused fro an already-running thread
    TCThreadCreateInfo createInfo = {};
    TCThread thread;

    result = CreateThread(createInfo, thread, true);

    if (result != TC_RESULT_SUCCESS) {
        Panic("CreateThread failed for the default thread.");
    }
    if (thread != 0) {
        Panic("CreateThread unexpectedly returned a non-zero thread ID.");
    }
}

}; // namespace TZmCFI

/* =========================================================================== *
 * Non-Secure application interface - starts here                              *
 * =========================================================================== */

extern "C" __attribute__((cmse_nonsecure_entry)) TCResult TCReset(void) noexcept {
    return TZmCFI::Reset();
}

extern "C" __attribute__((cmse_nonsecure_entry)) TCResult
TCCreateThread(TCThreadCreateInfo const *pCreateInfo, TCThread *thread) noexcept {
    // TODO: Validate pointers

    const TCThreadCreateInfo createInfo = *(TCThreadCreateInfo const *volatile)pCreateInfo;
    TCThread outThread;
    TCResult result = TZmCFI::CreateThread(createInfo, outThread, true);
    if (result == TC_RESULT_SUCCESS) {
#if TZMCFI_TRACE
        printf("TCCreateThread(...) -> %d\n", (int)outThread);
#endif
        *(TCThread volatile *)thread = outThread;
    }
    return result;
}

extern "C" __attribute__((cmse_nonsecure_entry)) TCResult TCLockdown(void) noexcept {
    return TZmCFI::Lockdown();
}

extern "C" __attribute__((cmse_nonsecure_entry)) TCResult
TCActivateThread(TCThread thread) noexcept {
#if TZMCFI_TRACE
    printf("TCActivateThread(%d)\n", (int)thread);
#endif
    return TZmCFI::ActivateThread(thread);
}
