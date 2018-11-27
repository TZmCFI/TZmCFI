/*
 * An example Secure program for AN521 FPGA.
 */
#include <ARMCM33_TZ.h>
#include <string_view>

using namespace std::literals;
using std::uint32_t;

extern void *_MainStackTop;
extern "C" void HandleReset();

namespace Loader {
namespace {

typedef void (*ns_funcptr_void)(void) __attribute__((cmse_nonsecure_call));

[[noreturn]] void Main() {
    // Enable SecureFault, UsageFault, BusFault, and MemManage for ease of debugging
    SCB->SHCSR = 0b00000000'00001111'00000000'00000000;

    // Set up the Non-Secure regions
    SAU->RNR = 0;
    SAU->RBAR = 0x00200000;
    SAU->RLAR = 0x003fffe0 | SAU_RLAR_ENABLE_Msk;
    SAU->RNR = 1;
    SAU->RBAR = 0x2820'0000;
    SAU->RLAR = 0x283f'ffe0 | SAU_RLAR_ENABLE_Msk;
    // TODO: Non-Secure Callable region

    // Allow Non-Secure access to UART0
    SAU->RNR = 2;
    SAU->RBAR = 0x4020'0000;
    SAU->RLAR = 0x4020'0fe0 | SAU_RLAR_ENABLE_Msk;

    // Configure SECRESPCFG to disable bus error on security violation
    // *(volatile uint32_t *)0x5008'0010 &= ~(1 << 0);

    // Configure APB PPC EXP 1 NS (APBNSPPCEXP1) interface 5 to enable
    // Non-Secure access to UART0
    *(volatile uint32_t *)0x5008'0084 |= 1 << 5;

    // Configure APB PPC EXP 1 SP (APBSPPPCEXP1) interface 5 to enable
    // unprivileged access to UART0
    *(volatile uint32_t *)0x5008'00c4 |= 1 << 5;

    // Configure MPC to enable Non-Secure access to SSRAM1.
    const auto SSRAM1_MPC_BASE = (volatile uint32_t *)0x5800'7000;
    {
        const auto CTRL = SSRAM1_MPC_BASE;
        const auto BLK_MAX = SSRAM1_MPC_BASE + 0x10 / 4;
        const auto BLK_IDX = SSRAM1_MPC_BASE + 0x18 / 4;
        const auto BLK_LUT = SSRAM1_MPC_BASE + 0x1c / 4;

        *CTRL |= 1 << 8; // Enable autoincrement

        // Only the second half (`[BLX_MAX / 2, BLX_MAX - 1]`, which corresponds
        // to `[0, 0x001f'0000]`) is allocated for Non-Secure access.
        *BLK_IDX = *BLK_MAX / 2;
        for (uint32_t i = *BLK_MAX / 2; i > 0; --i) {
            *BLK_LUT = 0xffff'ffff;
        }
    }

    // Configure MPC to enable Non-Secure access to SSRAM3.
    const auto SSRAM3_MPC_BASE = (volatile uint32_t *)0x5800'9000;
    {
        const auto CTRL = SSRAM3_MPC_BASE;
        const auto BLK_MAX = SSRAM3_MPC_BASE + 0x10 / 4;
        const auto BLK_IDX = SSRAM3_MPC_BASE + 0x18 / 4;
        const auto BLK_LUT = SSRAM3_MPC_BASE + 0x1c / 4;

        *CTRL |= 1 << 8; // Enable autoincrement

        *BLK_IDX = 0;
        for (uint32_t i = *BLK_MAX; i > 0; --i) {
            *BLK_LUT = 0xffff'ffff;
        }
    }

    TZ_SAU_Enable();

    // Set the Non-Secure main stack
    __TZ_set_MSP_NS(*(uint32_t *)0x0020'0000);

    auto nsResetHandler = (ns_funcptr_void)(*(uint32_t *)0x0020'0004 & ~1); // Secure alias of 0x20'0004
    nsResetHandler();

    while (1)
        ;
}

[[noreturn]] void HandleUnknown(std::string_view message) {
    while (1)
        ;
}

using InterruptHandler = void (*)();
#define Unhandled(message) []() { HandleUnknown(message); }.operator InterruptHandler()

}; // namespace

/**
 * Arm-M exception vector table.
 */
__attribute__((section(".isr_vector"))) uint32_t ExceptionVector[] = {
    (uint32_t)&_MainStackTop,
    (uint32_t)&HandleReset,                        // Reset
    (uint32_t)Unhandled("NMI"sv),                  // NMI
    (uint32_t)Unhandled("HardFault"sv),            // HardFault
    (uint32_t)Unhandled("MemManage"sv),            // MemManage
    (uint32_t)Unhandled("BusFault"sv),             // BusFault
    (uint32_t)Unhandled("UsageFault"sv),           // UsageFault
    (uint32_t)Unhandled("SecureFault"sv),          // SecureFault
    (uint32_t)Unhandled("Reserved 1"sv),           // Reserved 1
    (uint32_t)Unhandled("Reserved 2"sv),           // Reserved 2
    (uint32_t)Unhandled("Reserved 3"sv),           // Reserved 3
    (uint32_t)Unhandled("SVCall"sv),               // SVCall
    (uint32_t)Unhandled("DebugMonitor"sv),         // DebugMonitor
    (uint32_t)Unhandled("Reserved 4"sv),           // Reserved 4
    (uint32_t)Unhandled("PendSV"sv),               // PendSV
    (uint32_t)Unhandled("SysTick"sv),              // SysTick
    (uint32_t)Unhandled("External interrupt 0"sv), // External interrupt 0
    (uint32_t)Unhandled("External interrupt 1"sv), // External interrupt 1
    (uint32_t)Unhandled("External interrupt 2"sv), // External interrupt 2
    (uint32_t)Unhandled("External interrupt 3"sv), // External interrupt 3
    (uint32_t)Unhandled("External interrupt 4"sv), // External interrupt 4
    (uint32_t)Unhandled("External interrupt 5"sv), // External interrupt 5
    (uint32_t)Unhandled("External interrupt 6"sv), // External interrupt 6
    (uint32_t)Unhandled("External interrupt 7"sv), // External interrupt 7
    (uint32_t)Unhandled("External interrupt 8"sv), // External interrupt 8
};
}; // namespace Loader

// Called by the reset handler
extern "C" [[noreturn]] void AppMain() { Loader::Main(); }
