/*
 * Example program for AN521 FPGA.
 */
#include <ARMCM33_TZ.h>
#include <algorithm>
#include <array>

#include "FreeRTOS.h"
#include "task.h"

#include "An521.hpp"
#include "Base64.hpp"
#include "Pl011Driver.hpp"

using namespace std::literals;
using std::array;
using std::size_t;
using std::uint32_t;

extern void *_MainStackTop;
extern "C" void HandleReset();

extern "C" const uint32_t ExceptionVector[];

namespace TCExample {
namespace {

const Pl011Driver Uart{An521::Uart0BaseAddress};

constexpr uint32_t SystemCoreClock = 25'000'000;
constexpr uint32_t UartBaudRate = 115'200;

void IdleTaskMain(void *);

void Main() {
    // Configure APB PPC EXP 1 SP (APBNSPPPCEXP1) interface 5 to enable
    // Non-Secure unprivileged access to UART0
    *(volatile uint32_t *)0x4008'00c4 |= 1 << 5;

    Uart.Configure(SystemCoreClock, UartBaudRate);
    Uart.WriteAll("I'm running in the Non-Secure mode.\r\n"sv);

    // Disable exception trampolines (for comparative experiments)
    if (true) {
        // Set the Non-Secure exception vector table
        SCB->VTOR = reinterpret_cast<uint32_t>(ExceptionVector);
    }

    static StackType_t taskStack[configMINIMAL_STACK_SIZE] __attribute__((aligned(32)));
    TaskParameters_t taskParams = {
        .pvTaskCode = IdleTaskMain,
        .pcName = "saluton",
        .usStackDepth = configMINIMAL_STACK_SIZE,
        .pvParameters = NULL,
        .uxPriority = tskIDLE_PRIORITY,
        .puxStackBuffer = taskStack,
        .xRegions = {
            {(void *)An521::Uart0BaseAddress, 0x1000,
             tskMPU_REGION_READ_WRITE | tskMPU_REGION_EXECUTE_NEVER | tskMPU_REGION_DEVICE_MEMORY},
            {0, 0, 0},
            {0, 0, 0},
        }};
    xTaskCreateRestricted(&(taskParams), NULL);

    Uart.WriteAll("Entering the scheduler.\r\n"sv);
    vTaskStartScheduler();

    Uart.WriteAll("System halted.\r\n"sv);

    while (1)
        ;
}

void IdleTaskMain(void *) {
    Uart.WriteAll("Can I output to UART?\r\n"sv);

    while (1)
        ;
}

[[noreturn]] void HandleUnknown(std::string_view message) {
    Uart.WriteAll("Caught an unhandled exception ("sv);
    Uart.WriteAll(message);
    Uart.WriteAll("). Aborting.\n"sv);
    while (1)
        ;
}

}; // namespace
}; // namespace TCExample

// Called by the reset handler
extern "C" void AppMain() { TCExample::Main(); }

extern "C" void SysTick_Handler();
extern "C" void PendSV_Handler();
extern "C" void SVC_Handler();

using InterruptHandler = void (*)();
#define Unhandled(message) []() { TCExample::HandleUnknown(message); }.operator InterruptHandler()

/**
 * Arm-M exception vector table.
 */
alignas(128) const uint32_t ExceptionVector[] = {
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
    (uint32_t)&SVC_Handler,                        // SVCall
    (uint32_t)Unhandled("DebugMonitor"sv),         // DebugMonitor
    (uint32_t)Unhandled("Reserved 4"sv),           // Reserved 4
    (uint32_t)&PendSV_Handler,                     // PendSV
    (uint32_t)&SysTick_Handler,                    // SysTick
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
