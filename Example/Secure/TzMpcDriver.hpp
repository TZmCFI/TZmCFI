#pragma once

#include <cstdint>

#include "../App/Utils.hpp"

namespace TCExample {
/**
 * The device driver for the TrustZone Memory Protection Controller.
 * It is documented in the ARM CoreLink SIE-200 System IP for Embedded TRM
 * (DDI 0571G):
 * https://developer.arm.com/products/architecture/m-profile/docs/ddi0571/g
 */
class TzMpc {
  public:
    constexpr TzMpc(std::intptr_t baseAddress) : baseAddress{baseAddress} {}

    void AssignRangeToNonSecure(std::uint32_t start, std::uint32_t end) const {
        UpdateRange(start, end, 0, 0xffffffff);
    }

    void AssignRangeToSecure(std::uint32_t start, std::uint32_t end) const {
        UpdateRange(start, end, 0, 0);
    }

    void SetEnableBusError(bool e) const {
        auto value = ReadVolatile<std::uint32_t>(baseAddress);
        if (e) {
            value |= 1 << 4;
        } else {
            value &= ~(std::uint32_t{1} << 4);
        }
        WriteVolatile(baseAddress, value);
    }

  private:
    std::intptr_t const baseAddress;

    void UpdateRange(std::uint32_t start, std::uint32_t end, std::uint32_t andMask,
                     std::uint32_t xorMask) const;

    std::uint32_t GetBlockSizeShift() const {
        return ReadVolatile<std::uint32_t>(baseAddress + 0x14) + 5;
    }

    void SetEnableAutoIncrement(bool e) const {
        auto value = ReadVolatile<std::uint32_t>(baseAddress);
        if (e) {
            value |= 1 << 8;
        } else {
            value &= ~(std::uint32_t{1} << 8);
        }
        WriteVolatile(baseAddress, value);
    }

    void SeekToGroup(std::uint32_t i) const { WriteVolatile(baseAddress + 0x18, i); }

    void WriteGroupLut(std::uint32_t bits) const { WriteVolatile(baseAddress + 0x1c, bits); }

    std::uint32_t ReadGroupLut() const { return ReadVolatile<std::uint32_t>(baseAddress + 0x1c); }

    void UpdateGroupLut(std::uint32_t andMask, std::uint32_t xorMask) const {
        WriteGroupLut((ReadGroupLut() & andMask) ^ xorMask);
    }
};
} // namespace TCExample
