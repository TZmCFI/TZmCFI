#pragma once

#include <cstdint>
#include <ARMCM33_TZ.h>

namespace TCExample {
namespace An521 {
// UART 0 - J10 port
constexpr std::uint32_t Uart0BaseAddress = 0x40200000;

// Timer 0 (CMSDK timer)
constexpr std::uint32_t Timer0BaseAddress = 0x40000000;
constexpr IRQn_Type Timer0_IRQn = Interrupt3_IRQn;

// Timer 1 (CMSDK timer)
constexpr std::uint32_t Timer1BaseAddress = 0x40001000;
constexpr IRQn_Type Timer1_IRQn = Interrupt4_IRQn;

// Dual Timer (CMSDK dual timer)
constexpr std::uint32_t DualTimerBaseAddress = 0x40002000;
constexpr IRQn_Type DualTimer_IRQn = Interrupt5_IRQn;
}; // namespace An512
}; // namespace TCExample
