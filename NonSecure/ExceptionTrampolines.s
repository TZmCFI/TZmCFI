    .syntax unified
    .cpu cortex-m33
    .fpu softvfp
    .thumb

    // How many entries do we generate?
    .set TableSize, 20

// This assembler source defines the "real" Non-Secure exception vector table.
.section .text.isr_vector
ExceptionVectorWithTrampoline:
    .word TableSize // Initial stack pointer - we don't use it so
                    // store the number of entries instead
    .word Reset

    .set i, 0
    .rept TableSize - 2
        .word NormalExceptionTrampolines + 8 * i
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
    ldr r0, =ExceptionVector
    ldr sp, [r0]
    ldr pc, [r0, 4]

    .ltorg

    // The following code is registered as the "real" exception handlers.
    //
    // Align these trampolines to 8-byte blocks for easier (and faster)
    // exception-entry checking. Note that each trampoline also must be
    // no larger than 8 bytes.
    .thumb_func
    .type NormalExceptionTrampolines function
    .align 3
NormalExceptionTrampolines:
    .set i, 0
    .rept TableSize - 2
        .align 3

        // Disable interrupts before doing anything else
        cpsid f

        // Provide the location of the inner trampoline,
        // which is defined below
        adr.n r0, InnerExceptionTrampolines + i * 16
        b .LInvokeSecureTrampoline

        .set i, i + 1
    .endr

.LInvokeSecureTrampoline:
    // r0 = Address to the inner trampoline

    // Jump to the secure part of the exception trampoline.
    ldr r1, =__TCPrivateEnterInterrupt
    bx r1

    .ltorg

// The inner exception trampoline is responsible for two things:
//  1. `FAULTMASK_NS` is disabled (= interrupts are enabled) before calling the
//     original exception handler.
//  2. Branch to the exception return trampoline after the original exception
//     handler completes execution.
    .align 4
InnerExceptionTrampolines:
    .set i, 0
    .rept TableSize - 2
        // Each iteration generates a single inner trampoline, which must be
        // exactly 16 bytes large.
        .align 4

        // Figure out the address of the original exception handler. Use `lr`
        // as the scratch register because the exception return trampoline
        // ensures its integrity.
        ldr lr, =ExceptionVector + (i + 2) * 4

        // Re-enable interrupts.
        cpsie f

        ldr lr, [lr]
        blx lr

        b .LInvokeSecureReturnTrampoline

        .set i, i + 1
    .endr

.LInvokeSecureReturnTrampoline:
    // Disable interrupts.
    cpsid f

    // Jump to the secure part of the exception trampoline.
    ldr r0, =__TCPrivateLeaveInterrupt
    bx r0

    .ltorg
