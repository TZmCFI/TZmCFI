#pragma once

namespace TZmCFI {

/**
 * Loads the location information of Non-Secure exception trampolines from
 * a Non-Secure exception vector table.
 */
void InitializeShadowExceptionStack(uintptr_t const *nonSecureVectorTable);

} // namespace TZmCFI
