#include <array>
#include <cstdint>

#include <TZmCFI/PrivateGateway.h>

#include "Assert.hpp"

using std::uint32_t;

namespace TZmCFI {
namespace {

/**
 * A copy of a portion of an exception frame.
 */
struct ShadowExceptionFrame {
    /** The saved (original) program counter. */
    uint32_t pc;

    /** The saved (original) value of the LR register. */
    uint32_t lr;

    /** The `EXC_RETURN` value of the corresponding exception activation. */
    uint32_t exc_return;

    /** The original location of the exception frame. */
    uint32_t frame;
};

std::array<ShadowExceptionFrame, 32> g_stack;
ShadowExceptionFrame *g_stackTop = g_stack.data();

void EnterInterrupt(void (*isrBody)()) {
    // Note: We can't modify `sp` in this function, so we have to keep an eye
    //       on the assembler output of this function.

    uint32_t exc_return;
    asm volatile("mov %0, lr" : "=r"(exc_return)::);

    g_stackTop->exc_return = exc_return;
    g_stackTop++;

    // TODO: Implement shadow exception stack

    asm volatile("    adr lr, __TCPrivateLeaveInterrupt \n"
                 "    bxns %0 \n"
                 :
                 : "r"(isrBody)
                 :);

    __builtin_unreachable();
}

void LeaveInterrupt() {
    // Note: We can't modify `sp` in this function, so we have to keep an eye
    //       on the assembler output of this function.

    g_stackTop--;
    uint32_t exc_return = g_stackTop->exc_return;

    asm volatile("bx %0" : : "r"(exc_return) :);

    __builtin_unreachable();
}

} // namespace
} // namespace TZmCFI

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
