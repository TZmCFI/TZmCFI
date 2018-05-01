#pragma once
#include <atomic>
#include <optional>

namespace TZmCFI {

/**
 * A mutual exclusion primitive. Used to protect the internal structure from
 * simultaneous Non-Secure accesses.
 */
class Mutex {
  public:
    /**
     * Tries to acquire a lock. Returns `false` on failure.
     */
    bool TryLock() noexcept { return !locked.exchange(true, std::memory_order_acquire); }

    /**
     * Release a lock.
     */
    void Unlock() noexcept { locked.store(false, std::memory_order_release); }

  private:
    std::atomic<bool> locked{false};
};

/**
 * RAII lock guard.
 */
template <class T> class LockGuard {
  public:
    LockGuard(const LockGuard &) = delete;
    void operator=(const LockGuard &) = delete;

    std::optional<LockGuard> TryLock(T &mutex) noexcept {
        if (mutex.TryLock()) {
            return LockGuard{mutex};
        } else {
            return {};
        }
    }

    ~LockGuard() noexcept { mutex.Unlock(); }

  private:
    LockGuard(T &mutex) noexcept : mutex{mutex} {}

    T &mutex;
};

}; // namespace TZmCFI
