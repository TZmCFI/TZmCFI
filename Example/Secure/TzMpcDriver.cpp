#include <array>

#include "TzMpcDriver.hpp"

using std::uint32_t;

namespace TCExample {

namespace {

/**
 * Returns `0b11111000...000` where the number of trailing zeros is specified by
 * `position`. `position` must be less than 32.
 */
uint32_t U32OnesFromUnchecked(uint32_t position) { return (uint32_t)(-1) << position; }

/**
 * Returns `0b11111000...000` where the number of trailing zeros is specified by
 * `position`.
 */
uint32_t U32OnesFrom(uint32_t position) {
    return position == 32 ? 0 : ((uint32_t)(-1) << position);
}

std::array<uint32_t, 2> FilterMask(uint32_t andMask, uint32_t xorMask, uint32_t filter) {
    return {{andMask & ~filter, xorMask & filter}};
}

}; // namespace

void TzMpc::UpdateRange(uint32_t start, uint32_t end, uint32_t andMask, uint32_t xorMask) const {
    auto blockSizeShift = GetBlockSizeShift();
    start >>= blockSizeShift;
    end >>= blockSizeShift;

    if (start >= end) {
        return;
    }

    uint32_t startGroup = start / 32;
    uint32_t endGroup = end / 32;

    SetEnableAutoIncrement(false);
    SeekToGroup(startGroup);

    if (startGroup == endGroup) {
        auto masks = FilterMask(andMask, xorMask, U32OnesFrom(start % 32) ^ U32OnesFrom(end % 32));
        UpdateGroupLut(masks[0], masks[1]);
    } else {
        uint32_t group = startGroup;

        if ((start % 32) != 0) {
            auto masks = FilterMask(andMask, xorMask, U32OnesFrom(start % 32));
            UpdateGroupLut(masks[0], masks[1]);
            SeekToGroup(++group);
        }

        while (group < endGroup) {
            UpdateGroupLut(andMask, xorMask);
            SeekToGroup(++group);
        }

        if ((end % 32) != 0) {
            auto masks = FilterMask(andMask, xorMask, ~U32OnesFrom(end % 32));
            UpdateGroupLut(masks[0], masks[1]);
        }
    }
}

}; // namespace TCExample
