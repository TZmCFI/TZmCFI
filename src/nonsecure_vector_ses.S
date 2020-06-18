#include <TZmCFI/Trampolines.h>

    .syntax unified
    .cpu cortex-m33
    .fpu softvfp
    .thumb

    // How many entries do we generate?
    .set TableSize, 124 + 16

// This assembler source defines the "real" Non-Secure exception vector table.
.section .text.isr_vector
TCProtectedExceptionVectorTable:
    // Initial stack pointer - we don't use it so store the number of entries instead
    .word TableSize | TC_VEC_TABLE_HDR_SIGNATURE
    .word Reset

    .set i, 0
    .rept TableSize - 2
        .word ExceptionTrampolinesStage0 + TC_VEC_TABLE_TRAMPOLINE_STRIDE * i
        .set i, i + 1
    .endr

    // Executable code follows...
.section .text.ExceptionTrampolines

    .thumb_func
    .type Reset function
    .align 2
Reset:
    // The reset handler trampoline simply calls the original reset handler
    // after configuring the stack pointer
    ldr r0, =raw_exception_vectors
    ldr sp, [r0]
    ldr pc, [r0, 4]

    .ltorg

    // The following code is registered as the "real" exception handlers.
    //
    // Align these trampolines to 8-byte blocks for easier (and faster)
    // exception-entry checking. Note that each trampoline also must be
    // no larger than 8 bytes.
    .thumb_func
    .type ExceptionTrampolinesStage0 function
    .align 3 // == log2(TC_VEC_TABLE_TRAMPOLINE_STRIDE)
ExceptionTrampolinesStage0:
    .set i, 0
    .rept TableSize - 2
        // Disable interrupts before doing anything else
        cpsid f

        // Provide the location of the inner trampoline,
        // which is defined below
        adr.n r0, ExceptionTrampolinesStage2 + i * 16
        b .LExceptionTrampolineStage1

        .align 3
        .set i, i + 1
    .endr

.LExceptionTrampolineStage1:
    // r0 = stage2
    // lr = EXC_RETURN

    // Jump to the secure part of the exception trampoline.
    ldr r1, =__TCPrivateEnterInterrupt
    bx r1

    .ltorg

// The inner exception trampoline is responsible for two things:
//  1. Disable `FAULTMASK_NS` (enable interrupts) before calling the
//     original exception handler.
//  2. Branch to the exception return trampoline after the original exception
//     handler completes execution.
    .align 4
ExceptionTrampolinesStage2:
    .set i, 0
    .rept TableSize - 2
        // Each iteration generates a single inner trampoline, which must be
        // exactly 16 bytes large.
        .align 4

        // Figure out the address of the original exception handler. Use `lr`
        // as the scratch register because the exception return trampoline
        // ensures its integrity.
        ldr lr, =raw_exception_vectors + (i + 2) * 4

        // Re-enable interrupts.
        cpsie f

        // r0 = EXC_RETURN
        ldr lr, [lr]
        blx lr

        b .LExceptionReturnTrampoline

        .set i, i + 1
    .endr

.LExceptionReturnTrampoline:
    // Disable interrupts.
    cpsid f

    // Jump to the secure part of the exception trampoline.
    ldr r0, =__TCPrivateLeaveInterrupt
    bx r0

    .ltorg
