/*
 * An example Secure program for AN521 FPGA.
 */
#include <ARMCM33_TZ.h>
#include <string_view>

#include <TZmCFI/Secure.h>

#include "TzMpcDriver.hpp"

using namespace std::literals;
using std::uint32_t;
using std::uintptr_t;

extern void *_MainStackTop;
extern "C" void HandleReset();

extern void *__nsc_start;
extern void *__nsc_end;

namespace Loader {
namespace {

typedef void (*ns_funcptr_void)(void) __attribute__((cmse_nonsecure_call));

[[noreturn]] void Main() {
    // Enable SecureFault, UsageFault, BusFault, and MemManage for ease of debugging
    SCB->SHCSR = 0b00000000'00001111'00000000'00000000;

    // Enable Non-Secure BusFault, HardFault, and NMI.
    // Prioritize Secure exceptions.
    SCB->AIRCR = (SCB->AIRCR & ~SCB_AIRCR_VECTKEY_Msk) |
        SCB_AIRCR_BFHFNMINS_Msk | SCB_AIRCR_PRIS_Msk |
        (0x05faUL << SCB_AIRCR_VECTKEY_Pos);

    // Set up the Non-Secure regions
    SAU->RNR = 0;
    SAU->RBAR = 0x00200000;
    SAU->RLAR = 0x003fffe0 | SAU_RLAR_ENABLE_Msk;
    SAU->RNR = 1;
    SAU->RBAR = 0x2820'0000;
    SAU->RLAR = 0x283f'ffe0 | SAU_RLAR_ENABLE_Msk;

    // Non-Secure callable region
    SAU->RNR = 2;
    SAU->RBAR = reinterpret_cast<uint32_t>(&__nsc_start);
    SAU->RLAR = (reinterpret_cast<uint32_t>(&__nsc_end) - 0x20) |
        SAU_RLAR_ENABLE_Msk | SAU_RLAR_NSC_Msk;

    // Allow Non-Secure access to peripherals
    SAU->RNR = 3;
    SAU->RBAR = 0x4000'0000;
    SAU->RLAR = 0x4fff'ffe0 | SAU_RLAR_ENABLE_Msk;

    // Target interrupts to Non-Secure
    NVIC_SetTargetState(Interrupt3_IRQn); // Timer 0
    NVIC_SetTargetState(Interrupt4_IRQn); // Timer 1
    NVIC_SetTargetState(Interrupt5_IRQn); // Dual Timer
    NVIC_SetTargetState((IRQn_Type)32); // UART 0
    NVIC_SetTargetState((IRQn_Type)33); // UART 0

    // Configure SECRESPCFG to enable bus error on security violation (rather
    // than RAZ/WI)
    *(volatile uint32_t *)0x5008'0010 |= 1 << 0;

    // Enable the Non-Secure Callable setting of IDAU to allow the placement of
    // Non-Secure Callable regions in the code region.
    *(volatile uint32_t *)0x5008'0014 |= 1 << 0; // CODENSC

    // Configure APB PPC 0 NS (APBNSPPC0) interface 2:0 to enable
    // Non-Secure access to Timer 0 / Timer 1 / Dual Timer
    *(volatile uint32_t *)0x5008'0070 |= 0b111;

    // Configure APB PPC EXP 1 NS (APBNSPPCEXP1) interface 5 to enable
    // Non-Secure access to UART0
    *(volatile uint32_t *)0x5008'0084 |= 1 << 5;

    // Configure APB PPC EXP 1 SP (APBSPPPCEXP1) interface 5 to enable
    // unprivileged access to UART0
    *(volatile uint32_t *)0x5008'00c4 |= 1 << 5;

    // Configure MPC to enable Non-Secure access to SSRAM1
    // for the range `[0x20'0000, 0x3f'ffff]`.
    constexpr TCExample::TzMpc Ssram1Mpc{0x5800'7000};
    Ssram1Mpc.SetEnableBusError(true);
    Ssram1Mpc.AssignRangeToNonSecure(0x20'0000, 0x40'0000);

    // Configure MPC to enable Non-Secure access to SSRAM3 (`0x[23]8200000`)
    // for the range `[0, 0x1f'ffff]`.
    constexpr TCExample::TzMpc IramMpc{0x5800'9000};
    IramMpc.SetEnableBusError(true);
    IramMpc.AssignRangeToNonSecure(0, 0x20'0000);

    TZ_SAU_Enable();

    // Do not set the Non-Secure main stack using the value of `0x0020'0000`
    // here -- the place is used for other purposes and loading it as a stack
    // pointer is UNPREDICTABLE
    __TZ_set_MSP_NS(0);

    // Set the Non-Secure exception vector table
    SCB_NS->VTOR = 0x0020'0000;

    // Initialize TZmCFI.
    TCInitialize(reinterpret_cast<uintptr_t const *>(0x0020'0000));

    auto nsResetHandler = (ns_funcptr_void)(*(uint32_t *)0x0020'0004 & ~1);
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
