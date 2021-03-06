  .syntax unified
  .thumb
  .cpu cortex-m33
  .fpu softvfp

.section  .text.handleReset
  .weak  handleReset
  .type  handleReset, %function
handleReset:
  ldr   sp, =_main_stack_top      /* set stack pointer */

/* Copy the data segment initializers from flash to SRAM */
  movs  r1, #0
  b  LoopCopyDataInit

CopyDataInit:
  ldr  r3, =_sidata
  ldr  r3, [r3, r1]
  str  r3, [r0, r1]
  adds  r1, r1, #4

LoopCopyDataInit:
  ldr  r0, =_sdata
  ldr  r3, =_edata
  adds  r2, r0, r1
  cmp  r2, r3
  bcc  CopyDataInit
  ldr  r2, =_sbss
  b  LoopFillZerobss
/* Zero fill the bss segment. */
FillZerobss:
  movs  r3, #0
  str  r3, [r2], #4

LoopFillZerobss:
  ldr  r3, = _ebss
  cmp  r2, r3
  bcc  FillZerobss

/* Copy the fast-text section to RAM */
  movs  r1, #0
  b LoopCopyFastText
CopyFastText:
  ldr  r3, =_sifasttext
  ldr  r3, [r3, r1]
  str  r3, [r0, r1]
  adds  r1, r1, #4

LoopCopyFastText:
  ldr  r0, =_sfasttext
  ldr  r3, =_efasttext
  adds  r2, r0, r1
  cmp  r2, r3
  bcc  CopyFastText

#if SET_ORIGINAL_VTOR
  // Disable TZmCFI's exception trampolines by updating VTOR to the
  // original (unpatched) vector table.
  // (VTOR is supposed to be immutable in a production envrionment because
  // changing it compromises TZmCFI's integrity.)
  .global raw_exception_vectors
  ldr r0, =raw_exception_vectors
  ldr r1, =0xe000ed08 // VTOR
  str r0, [r1]
#endif

  b  main
  bx  lr
.size  handleReset, .-handleReset

// Provide a default definiton of the fast-text section
// (used if the target-specific linker script does not provide one)
.section  .text.defaultfasttext
  .weak  _sifasttext
  .weak  _sfasttext
  .weak  _efasttext
_sifasttext:
_sfasttext:
_efasttext:
