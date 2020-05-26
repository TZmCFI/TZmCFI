MEMORY
{
    /* Flash memory */
    CODEMEM (rx) : ORIGIN = 0x00010000, LENGTH = 566K
    /* SRAM 1–3 */
    SRAM (rwx) : ORIGIN = 0x20010000, LENGTH = 192K
}

ENTRY(handleReset)

SECTIONS
{
    .text.isr_vector :
    {
        . = ALIGN(128);
        *(.text.isr_vector*);
        KEEP(*(.text.isr_vector*))

        . = ALIGN(128);
        *(.text.raw_isr_vector*);
        KEEP(*(.text.raw_isr_vector*))
    } > CODEMEM

    privileged_functions :
    {
        . = ALIGN(32);
        __privileged_functions_start__ = .;
        *(privileged_functions)
        . = ALIGN(32);
        __privileged_functions_end__ = . - 1;
    } > CODEMEM

    freertos_system_calls :
    {
        . = ALIGN(32);
        __syscalls_flash_start__ = .;
        *(freertos_system_calls)
        . = ALIGN(32);
        __syscalls_flash_end__ = . - 1;
    } > CODEMEM

    .text :
    {
        __text = .;
        *(.text.isr_vector)
        *(.text.ExceptionTrampolines)
        *(.text.rom_padding)
        KEEP (*(.text.rom_padding))
        *(.text)
        *(.text*)
        *(.eh_frame)

        KEEP (*(.init))
        KEEP (*(.fini))

    } > CODEMEM

    _etext = .;
    PROVIDE(etext = .);

    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > CODEMEM

    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > CODEMEM
    __exidx_start = .;
    .ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } > CODEMEM
    __exidx_end = .;

    __unprivileged_flash_end__ = .;

    privileged_data :
    {
        . = ALIGN(32);
        __privileged_sram_start__ = .;
        *(privileged_data)
        . = ALIGN(32);
        __privileged_sram_end__ = .  -1;
    } > SRAM

    /* used by the startup to initialize data */
    _sidata = LOADADDR(.data);

    /* Initialized data sections goes into RAM, load LMA copy after code */
    .data :
    {
        . = ALIGN(4);
        _sdata = .;        /* create a global symbol at data start */
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end */
    } >SRAM AT> CODEMEM


    /* Uninitialized data section */
    . = ALIGN(4);
    .bss :
    {
        /* This is used by the startup in order to initialize the .bss secion */
        _sbss = .;         /* define a global symbol at bss start */
        __bss_start__ = _sbss;
        *(.bss)
        *(.bss*)
        *(COMMON)

        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end */
        __bss_end__ = _ebss;
    } >SRAM

    /* Reserve stack space */
    . = ALIGN(8);
    . = . + 0x4000;
    PROVIDE(_main_stack_top = .);

    _end = .;
    PROVIDE(end = .);
}
