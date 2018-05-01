#pragma once

namespace TZmCFI {

/**
 * Aborts the program with a given error message.
 */
[[noreturn]] void Panic(const char *message) noexcept;

/**
 * Placeholder for making unimplemented code. Aborts the program with a message
 * saying that such code was reached.
 */
[[noreturn]] inline void Unimplemented() noexcept { Panic("unimplemented"); }

}; // namespace TZmCFI
