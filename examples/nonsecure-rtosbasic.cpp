#include "FreeRTOS.h"
#include "timers.h"

// Trampolines
//
// The icall sanitizer (`-fsanitize=cfi`) utilizes type metadata attached to
// functions. The metadata encodes the C/C++ signature of the attached function,
// which is used to check the type-correctness of function pointers being called.
// This means a compiler must emit type metadata for indirect function calls to
// work. Unfortunately, Zig doesn't do that. Without that, indirect calls to
// a Zig function always fail.
//
// Generating type metadata is not easy because it requires a mangled type name
// that perfectly agrees with what the callsite expects, but applying a C++
// mangling scheme on Zig types isn't trivial. As a quick work-around, we define
// an indirectly-callable trampoline function in a C/C++ source file.

extern "C" void timerHandler(TimerHandle_t xTimer);
// `TimerCallbackFunction_t`, `_ZTSFvP15tmrTimerControlE`
static void trampoline_timerHandler(TimerHandle_t xTimer) { timerHandler(xTimer); }
extern "C" void (*getTrampoline_timerHandler())(TimerHandle_t) { return trampoline_timerHandler; }
