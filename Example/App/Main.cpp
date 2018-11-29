/*
 * Example program for AN521 FPGA.
 */
#include <ARMCM33_TZ.h>
#include <algorithm>
#include <array>

#include "An521.hpp"
#include "Pl011Driver.hpp"

using namespace std::literals;
using std::uint32_t;

extern void *_MainStackTop;
extern "C" void HandleReset();

namespace TCExample {
namespace {

const Pl011Driver Uart{An521::Uart0BaseAddress};

constexpr uint32_t SystemCoreClock = 25'000'000;
constexpr uint32_t UartBaudRate = 115'200;

void Main() {
    Uart.Configure(SystemCoreClock, UartBaudRate);
    Uart.WriteAll("I'm running in the Non-Secure mode.\n"sv);

    NVIC_SetPriority(SysTick_IRQn, 0x4);
    SysTick->LOAD = 20000 - 1;
    SysTick->VAL = 0;
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;

    Uart.WriteAll("SysTick [A] is ready.\n"sv);

    NVIC_SetPriority(An521::Timer0_IRQn, 0x3);
    auto timer0 = reinterpret_cast<uint32_t volatile *>(An521::Timer0BaseAddress);
    timer0[2] = 20000 - 1; // reload value
    timer0[0] = 0b1001; // enable, IRQ enable
    NVIC_EnableIRQ(An521::Timer0_IRQn);

    Uart.WriteAll("Timer0 [B] is ready.\n"sv);

    while (1)
        ;
}

void Print(uint32_t i) {
    std::array<char, 10> buffer;
    std::size_t len = 0;
    while (i != 0) {
        buffer[len++] = '0' + (i % 10);
        i /= 10;
    }
    std::reverse(buffer.begin(), buffer.begin() + len);

    Uart.WriteAll({buffer.data(), len});
}

uint32_t counter1 = 1;
uint32_t counter2 = 1;
uint32_t historyValid = 0;
uint32_t historyType = 0;

void PrintTimerState() {
    Uart.WriteAll("\r ["sv);
    for (uint32_t i = 1; i < (1 << 16); i <<= 1) {
        if (historyValid & i) {
            if (historyType & i) {
                Uart.WriteAll('B');
            } else {
                Uart.WriteAll('A');
            }
        } else {
            Uart.WriteAll(' ');
        }
    }
    Uart.WriteAll("] "sv);
    Print(counter1);
    Uart.WriteAll(" / "sv);
    Print(counter2);
}

void HandleSysTick() {
    __disable_irq();

    ++counter2;
    historyValid = (historyValid << 1) | 1;
    historyType = (historyType << 1) | 0;

    PrintTimerState();

    __enable_irq();
}

void HandleTimer0() {
    auto timer0 = reinterpret_cast<uint32_t volatile *>(An521::Timer0BaseAddress);
    timer0[3] = 1;

    __disable_irq();

    ++counter1;
    historyValid = (historyValid << 1) | 1;
    historyType = (historyType << 1) | 1;

    PrintTimerState();

    __enable_irq();
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

using InterruptHandler = void (*)();
#define Unhandled(message) []() { TCExample::HandleUnknown(message); }.operator InterruptHandler()

extern "C" const uint32_t ExceptionVector[];

/**
 * Arm-M exception vector table.
 */
const uint32_t ExceptionVector[] = {
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
    (uint32_t)&TCExample::HandleSysTick,           // SysTick
    (uint32_t)Unhandled("External interrupt 0"sv), // External interrupt 0
    (uint32_t)Unhandled("External interrupt 1"sv), // External interrupt 1
    (uint32_t)Unhandled("External interrupt 2"sv), // External interrupt 2
    (uint32_t)&TCExample::HandleTimer0, // External interrupt 3
    (uint32_t)Unhandled("External interrupt 4"sv), // External interrupt 4
    (uint32_t)Unhandled("External interrupt 5"sv), // External interrupt 5
    (uint32_t)Unhandled("External interrupt 6"sv), // External interrupt 6
    (uint32_t)Unhandled("External interrupt 7"sv), // External interrupt 7
    (uint32_t)Unhandled("External interrupt 8"sv), // External interrupt 8
};
