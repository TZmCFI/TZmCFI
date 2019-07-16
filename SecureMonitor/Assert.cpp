#include "Assert.hpp"
#include <cstdlib>

namespace TZmCFI {

namespace {
void SemihostingOutput(const char *message) noexcept {
    while (*message) {
        asm volatile("mov r0, #0x03 \n\t" // TARGET_SYS_WRITEC
                     "mov r1, %0 \n\t"
                     "bkpt 0xab"
                     :
                     : "r"(message)
                     : "r0", "r1");
        ++message;
    }
}
}; // namespace

[[noreturn]] void Panic(const char *message) noexcept {
    // Disable interrupts
    asm volatile("cpsid f");

    SemihostingOutput("TZmCFI panic: ");
    SemihostingOutput(message);
    SemihostingOutput("\r\n");

    asm volatile("mov r0, #0x18 \n\t"    // TARGET_SYS_EXIT / angel_SWIreason_ReportException
                 "ldr r1, =0x20026 \n\t" // ADP_Stopped_ApplicationExit
                 "bkpt 0xab");

    while (1) {
    }
}

}; // namespace TZmCFI
