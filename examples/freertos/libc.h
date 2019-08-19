// These functions are provided by libc and defined by `stdlib.h` etc. However,
// Zig won't provide the header files because it thinks libc is unavailable for
// our target platform.
#pragma once

#include <stddef.h>

extern void *memcpy(void *dest, const void *src, size_t count);
extern void *memset(void *dest, int ch, size_t count);
