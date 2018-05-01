#include "LinearAllocator.hpp"
#include "Assert.hpp"

namespace TZmCFI {

std::optional<Allocation> BaseLinearAllocator::AllocateBytes(StorageView view, std::size_t size,
                                                             std::size_t align) noexcept {
    // Compute the new value of `top`
    std::size_t topAligned = (top + align - 1) & ~(align - 1);
    if (topAligned < top) {
        return {};
    }

    std::size_t pad = topAligned - top;

    std::size_t newTop = topAligned + size;
    if (newTop < topAligned) {
        return {};
    }

    // Check for overflow
    if (newTop > view.size) {
        return {};
    }

    char *ptr = view.data + topAligned;
    top = newTop;

    return Allocation{ptr, size, pad};
}

void BaseLinearAllocator::Deallocate(StorageView view, Allocation alloc) noexcept {
    std::size_t originalTopAligned = alloc.ptr - view.data;
    std::size_t originalTop = originalTopAligned - alloc.pad;
    std::size_t expectedTop = originalTopAligned + alloc.size;

    if (expectedTop != top) {
        Panic("LinearAllocator only can deallocate the object on the stack's top");
    }

    top = originalTop;
}

}; // namespace TZmCFI
