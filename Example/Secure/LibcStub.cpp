#include <cstdint>

extern "C" void *_sbrk_r(int incr) {
    extern char __heap_start; // set by linker
    extern char __heap_end;   // set by linker

    static char *heap_end; /* Previous end of heap or 0 if none */
    char *prev_heap_end;

    if (0 == heap_end) {
        heap_end = &__heap_start; /* Initialize first time round */
    }

    prev_heap_end = heap_end;
    heap_end += incr;
    // check
    if (heap_end < (&__heap_end)) {

    } else {
        return (char *)-1;
    }
    return (void *)prev_heap_end;
}

extern "C" void _close() {}

extern "C" void _read() {}

extern "C" void _fstat() {}

extern "C" void _isatty() {}

extern "C" void _lseek() {}

extern "C" std::size_t _write(int fd, const char *buf, std::size_t nbytes) {
    // Assuem `fd` is `stdout`
    for (const char *end = buf + nbytes; buf != end; ++buf) {
        asm volatile("mov r0, #0x03 \n\t" // TARGET_SYS_WRITEC
                     "mov r1, %0 \n\t"
                     "bkpt 0xab"
                     :
                     : "r"(buf)
                     : "r0", "r1");
    }
    return nbytes;
}
