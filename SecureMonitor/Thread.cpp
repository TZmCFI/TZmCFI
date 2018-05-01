#include <array>

#include <TZmCFI/Gateway.h>

#include "Assert.hpp"
#include "LinearAllocator.hpp"
#include "Mutex.hpp"

namespace TZmCFI {
namespace {

LinearAllocator<32768> g_arena;

struct NonSecureThread {};

std::array<NonSecureThread *, 256> g_threads;

// TODO: Critical section

TCResult Reset() noexcept {
    g_arena.Reset();
    return TC_RESULT_SUCCESS;
}

TCResult CreateThread(const TCThreadCreateInfo &createInfo, TCThread &outThread) noexcept {
    Unimplemented();
}

TCResult Lockdown() noexcept { Unimplemented(); }

TCResult ActivateThread(TCThread thread) noexcept { Unimplemented(); }

}; // namespace
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
    TZmCFI::Unimplemented();

    const TCThreadCreateInfo createInfo = *(TCThreadCreateInfo const *volatile)pCreateInfo;
    TCThread outThread;
    TCResult result = TZmCFI::CreateThread(createInfo, outThread);
    if (result != TC_RESULT_SUCCESS) {
        *(TCThread volatile *)thread = outThread;
    }
    return result;
}

extern "C" __attribute__((cmse_nonsecure_entry)) TCResult TCLockdown(void) noexcept {
    return TZmCFI::Lockdown();
}

extern "C" __attribute__((cmse_nonsecure_entry)) TCResult
TCActivateThread(TCThread thread) noexcept {
    return TZmCFI::ActivateThread(thread);
}
