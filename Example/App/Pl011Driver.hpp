#pragma once

#include <cstdint>
#include <string_view>

namespace TCExample {
/**
 * The device driver for Arm PrimCel UART (PL011).
 */
class Pl011Driver {
  public:
    constexpr Pl011Driver(std::intptr_t baseAddress) : baseAddress{baseAddress} {}

    void Configure(std::uint32_t systemCoreClock, std::uint32_t baudRate) const;

    /**
     * Transmits a byte. Returns whether it was successful (`false` indicates
     * failure).
     */
    bool Write(char data) const;

    /**
     * Transmits a byte. Uses polling to control the transmission rate.
     */
    void WriteAll(char data) const;

    /**
     * Transmits a string. Uses polling to control the transmission rate.
     */
    void WriteAll(std::string_view data) const;

  private:
    std::intptr_t const baseAddress;
};
}; // namespace TCExample
