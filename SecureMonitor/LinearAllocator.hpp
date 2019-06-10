#pragma once
#include <cstdint>
#include <optional>
#include <string_view>
#include <type_traits>
#include <utility>

namespace TZmCFI {

/**
 * Represents an allocated region on a `LinearAllocator`.
 */
struct Allocation {
    char *ptr;
    std::size_t size;
    std::size_t pad;
};

/**
 * Base class of `LinearAllocator`. Do not instantiate directly!
 */
class BaseLinearAllocator {
  protected:
    BaseLinearAllocator() noexcept : top{0} {}

    BaseLinearAllocator(const BaseLinearAllocator &) = delete;
    void operator=(const BaseLinearAllocator &) = delete;

    // I'm surprised that C++17 does not have a generic contiguous slice type!
    struct StorageView {
        char *data;
        std::size_t size;
    };

    std::optional<Allocation> AllocateBytes(StorageView, std::size_t size,
                                            std::size_t align) noexcept;

    void Deallocate(StorageView, Allocation alloc) noexcept;

  public:
    /**
     * Clears the memory pool.
     *
     * This method does not perform a de-initialization on the allocated values.
     */
    void Reset() noexcept { top = 0; }

  private:
    std::size_t top;
};

/**
 * Implements a stack-like dynamic memory allocator. Maintains a fixed size of
 * memory pool, as specified by the template parameter `Size`.
 *
 * Warning: This class is not thread-safe.
 */
template <std::size_t Size> class LinearAllocator final : public BaseLinearAllocator {
  public:
    LinearAllocator() = default;

    LinearAllocator(const LinearAllocator &) = delete;
    void operator=(const LinearAllocator &) = delete;

    /**
     * Allocates `size` bytes of uninitialized storage, aligned by `align` bytes.
     * Returns `nullptr` if something goes wrong or `count` is zero.
     */
    std::optional<Allocation> AllocateBytes(std::size_t size, std::size_t align = 1) noexcept {
        return BaseLinearAllocator::AllocateBytes(GetStorageView(), size, align);
    }

    /**
     * Allocates a `T` from the internal storage.
     * Returns `nullptr` if something goes wrong.
     *
     * This method does not perform an initialization on the allocated value.
     */
    template <class T> std::optional<std::pair<T *, Allocation>> Allocate() noexcept {
        auto alloc = AllocateBytes(sizeof(T), alignof(T));
        if (!alloc) {
            return {};
        }

        return std::make_pair(reinterpret_cast<T *>(alloc->ptr), *alloc);
    }

    /**
     * Deallocates a memory region. `allocation` must be the last allocation
     * performed on this `LinearAllocator` (otherwise it'll abort).
     *
     * This method does not perform a de-initialization on the allocated value.
     */
    void Deallocate(Allocation alloc) noexcept { Deallocate(GetStorageView(), alloc); }

  private:
    std::aligned_storage_t<Size> storage;

    StorageView GetStorageView() noexcept {
        return {reinterpret_cast<char *>(&storage), sizeof(storage)};
    }
};

}; // namespace TZmCFI
