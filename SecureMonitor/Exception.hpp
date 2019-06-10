#pragma once

#include <TZmCFI/Gateway.h>
#include <stdint.h>

namespace TZmCFI {

struct ShadowExceptionStackState {
    void *start;
    size_t size;
    void *top;
};

/**
 * Loads the location information of Non-Secure exception trampolines from
 * a Non-Secure exception vector table.
 */
void InitializeShadowExceptionStack(uintptr_t const *nonSecureVectorTable);

/**
 * Initialize `ShadowExceptionStackState` using the specified
 * `TCThreadCreateInfo`.
 *
 * `ShadowExceptionStackState::{stackStart, stackSize}` must be initialized by
 * the caller.
 *
 * `isRunning` is a flag indicating whether the thread is already in the running
 * state. If it's `true`, this function creates an empty stack; othersie, it
 * initializes with a simulated exception stack, which will be used when
 * resuming the thread from a PendSV handler.
 */
void CreateShadowExceptionStackState(const TCThreadCreateInfo &createInfo,
                                     ShadowExceptionStackState &state, bool isRunning);

/**
 * Save the state of the active shadow exception stack to the specified
 * `ShadowExceptionStackState`.
 *
 * `state` must be the `ShadowExceptionStackState` corresponding to the active
 * shadow exception stack.
 */
void SaveShadowExceptionStackState(ShadowExceptionStackState &state);

/**
 * Switch the active shadow exception stack to the one corresponding to the
 * specified `ShadowExceptionStackState`.
 */
void LoadShadowExceptionStackState(const ShadowExceptionStackState &state);

} // namespace TZmCFI
