#include <ARMCM33_TZ.h>
#include <algorithm>
#include <array>
#include <cstdint>

#include <TZmCFI/PrivateGateway.h>

#include "../NonSecure/ExceptionTrampolines.h"
#include "Assert.hpp"
#include "Exception.hpp"

using std::size_t;
using std::uintptr_t;

namespace TZmCFI {
namespace {

/**
 * A copy of a portion of an exception frame.
 */
struct ShadowExceptionFrame {
    /** The saved (original) program counter. */
    uintptr_t pc;

    /** The saved (original) value of the LR register. */
    uintptr_t lr;

    /** The `EXC_RETURN` value of the corresponding exception activation. */
    uintptr_t exc_return;

    /** The original location of the exception frame. */
    uintptr_t frame;

    bool operator==(const ShadowExceptionFrame &o) const {
        return pc == o.pc && lr == o.lr && exc_return == o.exc_return && frame == o.frame;
    }
    bool operator!=(const ShadowExceptionFrame &o) const { return !(*this == o); }
};

/**
 * Models a set of program counter values which are recognized as exception
 * entry.
 */
class ExecptionEntryPCSet {
    uintptr_t start = 0;
    uintptr_t len = 0;

  public:
    void InitializeFromVectorTable(uintptr_t const *nonSecureVectorTable) {
        uintptr_t size = nonSecureVectorTable[0];
        if ((size & TC_VEC_TABLE_HDR_SIGNATURE_MASK) != TC_VEC_TABLE_HDR_SIGNATURE) {
            Panic("TZmCFI magic number was not found in the Non-Secure exception vector table.");
        }
        size &= TC_VEC_TABLE_HDR_SIZE_MASK;

        if (size < 2) {
            Panic("The Non-Secure exception vector table is too small.");
        }

        if (size > 256) {
            Panic("The Non-Secure exception vector table is too large.");
        }

        if (size == 2) {
            len = 0;
            return;
        }

        start = nonSecureVectorTable[2];
        if (!(start & 1)) {
            Panic("The address of an exception trampoline is malformed.");
        }

        // Sanity check
        for (uintptr_t i = 2; i < size; ++i) {
            if (nonSecureVectorTable[i] != start + (i - 2) * TC_VEC_TABLE_TRAMPOLINE_STRIDE) {
                Panic("Some exception trampolines are not layouted as expected.");
            }
        }

        start &= ~1;
        len = (size - 2) * TC_VEC_TABLE_TRAMPOLINE_STRIDE;
    }

    bool Contains(uintptr_t pc) const {
        pc -= start;
        return pc < len && pc % TC_VEC_TABLE_TRAMPOLINE_STRIDE == 0;
    }
};

ExecptionEntryPCSet g_exceptionEntryPCSet;

/**
 * Iterates through the chained exception stack.
 */
class ChainedExceptionStackIterator {
    uintptr_t msp;
    uintptr_t psp;
    uintptr_t exc_return;
    uintptr_t const *frame;

    [[gnu::always_inline]] void FillFrameAddress() {
        if (exc_return & EXC_RETURN_SPSEL) {
            frame = reinterpret_cast<uintptr_t const *>(psp);
        } else {
            frame = reinterpret_cast<uintptr_t const *>(msp);
        }
    }

  public:
    ChainedExceptionStackIterator(uintptr_t exc_return, uintptr_t msp, uintptr_t psp)
        : msp{msp}, psp{psp}, exc_return{exc_return} {
        FillFrameAddress();
    }

    uintptr_t GetOriginalPC() const { return frame[6]; }
    uintptr_t GetOriginalLR() const { return frame[5]; }
    uintptr_t GetFrameAddress() const { return reinterpret_cast<uintptr_t>(frame); }
    uintptr_t GetExcReturn() const { return exc_return; }

    ShadowExceptionFrame AsShadowExceptionFrame() const {
        return {
            GetOriginalPC(),
            GetOriginalLR(),
            GetExcReturn(),
            GetFrameAddress(),
        };
    }

    /**
     * Moves to the next stack entry. Returns `false` if we can't proceed due
     * to one of the following reasons:
     *  - We reached the end of the chained exception stack.
     *  - We reached the end of the exception stack.
     */
    [[gnu::always_inline]] inline bool MoveNext() {
        if (exc_return & EXC_RETURN_MODE) {
            // Reached the end of the exception stack.
            return false;
        }

        if (!g_exceptionEntryPCSet.Contains(GetOriginalPC())) {
            // The background context is an exception activation that already
            // started running software code. Thus we reached the end of the
            // chained exception stack.
            // (Even if we go on, we wouldn't be able to retrieve the rest of
            // the exception stack because we can't locate exception frames
            // without doing DWARF CFI-based stack unwinding.)
            return false;
        }

        uintptr_t new_exc_return = GetOriginalLR();

        // Unwind the stack
        uintptr_t frameSize = (exc_return & EXC_RETURN_FTYPE) ? 32 : 104;
        if (exc_return & EXC_RETURN_SPSEL) {
            psp += frameSize;
        } else {
            msp += frameSize;
        }

        exc_return = new_exc_return;
        FillFrameAddress();

        return true;
    }
};

/** The default shadow stack */
std::array<ShadowExceptionFrame, 32> g_shadowStack;

ShadowExceptionFrame *g_shadowStackCurrent = g_shadowStack.data();
ShadowExceptionFrame *g_shadowStackTop = g_shadowStack.data();
ShadowExceptionFrame *g_shadowStackLimit = g_shadowStack.data() + g_shadowStack.size();

void PushShadowExceptionStack(uintptr_t exc_return, uintptr_t msp, uintptr_t psp) {
    ChainedExceptionStackIterator excStack{exc_return, msp, psp};

    ShadowExceptionFrame *newTop = g_shadowStackTop;

    // TODO: Add bounds check using `g_shadowStackLimit`

    if (g_shadowStackTop == g_shadowStackCurrent) {
        // The shadow exception stack is empty -- push every frame we find
        do {
            *newTop = excStack.AsShadowExceptionFrame();
            newTop++;
        } while (excStack.MoveNext());
    } else {
        // Push until a known entry is encountered
        uintptr_t topFrameAddress = (g_shadowStackTop - 1)->frame;

        do {
            if (excStack.GetFrameAddress() == topFrameAddress) {
                break;
            }
            *newTop = excStack.AsShadowExceptionFrame();
            newTop++;
        } while (excStack.MoveNext());
    }

    std::reverse(g_shadowStackTop, newTop);

    g_shadowStackTop = newTop;
}

[[noreturn]] void EnterInterrupt(void (*isrBody)()) {
    asm volatile("push {r0, lr} \n"
                 // Prepare parameteres of `PushShadowExceptionStack
                 "mov r0, lr \n"
                 "mrs r1, msp_ns \n"
                 "mrs r2, psp_ns \n"
                 "bl __PushShadowExceptionStack \n"
                 "pop {r0, r1} \n"
                 "adr lr, __TCPrivateLeaveInterrupt \n"
                 "bxns r0 \n");

    __builtin_unreachable();
}

uintptr_t AssertShadowExceptionStack(uintptr_t msp, uintptr_t psp) {
    if (g_shadowStackTop == g_shadowStackCurrent) {
        // Shadow stack is empty
        Panic("Exception return trampoline was called but the shadow exception stack is empty.");
    }

    uintptr_t exc_return = g_shadowStackTop[-1].exc_return;

    ChainedExceptionStackIterator excStack{exc_return, msp, psp};

    // Validate *two* top entries.
    if (excStack.AsShadowExceptionFrame() != g_shadowStackTop[-1]) {
        Panic("Exception stack integrity check has failed.");
    }
    if (excStack.MoveNext()) {
        if (g_shadowStackTop == g_shadowStackCurrent + 1) {
            Panic("The number of entries in the shadow exception stack is lower than expected.");
        }
        if (excStack.AsShadowExceptionFrame() != g_shadowStackTop[-2]) {
            Panic("Exception stack integrity check 2 has failed.");
        }
    }

    g_shadowStackTop--;
    return exc_return;
}

[[noreturn]] void LeaveInterrupt() {
    asm volatile("mrs r0, msp_ns \n"
                 "mrs r1, psp_ns \n"
                 "bl __AssertShadowExceptionStack \n"
                 "bx r0 \n");

    __builtin_unreachable();
}

} // namespace

void InitializeShadowExceptionStack(uintptr_t const *nonSecureVectorTable) {
    g_exceptionEntryPCSet.InitializeFromVectorTable(nonSecureVectorTable);
}

void CreateShadowExceptionStackState(const TCThreadCreateInfo &createInfo,
                                     ShadowExceptionStackState &state, bool isRunning) {
    size_t size = reinterpret_cast<size_t>(state.limit) - reinterpret_cast<size_t>(state.start);
    if (static_cast<ptrdiff_t>(size) < static_cast<ptrdiff_t>(sizeof(ShadowExceptionFrame))) {
        Panic("The shadow exception stack is too small.");
    }

    auto stack = reinterpret_cast<ShadowExceptionFrame *>(state.start);

    if (isRunning) {
        // Set the top pointer
        state.top = stack;
    } else {
        // Create a simulated exception frame
        stack[0].pc = createInfo.initialPC;
        stack[0].lr = createInfo.initialLR;
        stack[0].exc_return = createInfo.excReturn;
        stack[0].frame = createInfo.exceptionFrame;

        // Set the top pointer
        state.top = stack + 1;
    }
}

void SaveShadowExceptionStackState(ShadowExceptionStackState &state) {
    state.start = g_shadowStackCurrent;
    state.limit = g_shadowStackLimit;
    state.top = g_shadowStackTop;
}
void LoadShadowExceptionStackState(const ShadowExceptionStackState &state) {
    g_shadowStackCurrent = static_cast<ShadowExceptionFrame *>(state.start);
    g_shadowStackLimit = static_cast<ShadowExceptionFrame *>(state.limit);
    g_shadowStackTop = static_cast<ShadowExceptionFrame *>(state.top);
}

} // namespace TZmCFI

// Give demangled names to internal C++ functions
extern "C" void __PushShadowExceptionStack(uintptr_t exc_return, uintptr_t msp, uintptr_t psp) {
    TZmCFI::PushShadowExceptionStack(exc_return, msp, psp);
}

extern "C" uintptr_t __AssertShadowExceptionStack(uintptr_t msp, uintptr_t psp) {
    return TZmCFI::AssertShadowExceptionStack(msp, psp);
}

/* =========================================================================== *
 * Non-Secure application interface - starts here                              *
 * =========================================================================== */

extern "C" __attribute__((visibility("default"))) void
__TCPrivateEnterInterrupt(void (*isrBody)()) {
    asm volatile("sg");
    TZmCFI::EnterInterrupt(isrBody);
}

extern "C" __attribute__((visibility("default"))) void __TCPrivateLeaveInterrupt(void) {
    asm volatile("sg");
    TZmCFI::LeaveInterrupt();
}
