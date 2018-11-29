#include <TZmCFI/Secure.h>

#include "Exception.hpp"

/* =========================================================================== *
 * Secure application interface - starts here                                  *
 * =========================================================================== */

extern "C" void TCInitialize(uintptr_t const *nonSecureVectorTable) {
    TZmCFI::InitializeShadowExceptionStack(nonSecureVectorTable);
}
