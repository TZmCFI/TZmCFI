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

void PushShadowExceptionStack(uint32_t exc_return, uint32_t msp, uint32_t psp) {
    g_stackTop->exc_return = exc_return;
    g_stackTop++;

    // TODO: Implement shadow exception stack
}

[[noreturn]] void EnterInterrupt(void (*isrBody)()) {
    asm volatile("push {r0} \n"
                 // Prepare parameteres of `PushShadowExceptionStack
                 "mov r0, lr \n"
                 "bl __PushShadowExceptionStack \n"
                 "pop {r0} \n"
                 "adr lr, __TCPrivateLeaveInterrupt \n"
                 "bxns r0 \n");

    __builtin_unreachable();
}

uint32_t AssertShadowExceptionStack() {
    g_stackTop--;
    return g_stackTop->exc_return;
}

[[noreturn]] void LeaveInterrupt() {
    asm volatile("bl __AssertShadowExceptionStack \n"
                 "bx r0 \n");

    __builtin_unreachable();
}

} // namespace
} // namespace TZmCFI

// Give demangled names to internal C++ functions
extern "C" void __PushShadowExceptionStack(uint32_t exc_return, uint32_t msp, uint32_t psp) {
    TZmCFI::PushShadowExceptionStack(exc_return, msp, psp);
}

extern "C" uint32_t __AssertShadowExceptionStack(void) {
    return TZmCFI::AssertShadowExceptionStack();
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
