#pragma once
/*
 * This header file defines an interface from the software running in the
 * Secure mode for configuring the monitor program.
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void TCInitialize(uintptr_t const *nonSecureVectorTable);

#ifdef __cplusplus
}
#endif
