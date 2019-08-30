MEMORY
{
    /* AN505 ZBT SRAM (SSRAM1) Non-Secure alias */
    CODEMEM (rx) : ORIGIN = 0x00200000, LENGTH = 512K
    /* AN505 ZBT SRAM (SSRAM3) Non-Secure alias */
    SRAM (rwx) : ORIGIN = 0x28200000, LENGTH = 32K
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
        __privileged_functions_end__ = .;
    } > CODEMEM

    freertos_system_calls :
    {
        . = ALIGN(32);
        __syscalls_flash_start__ = .;
        *(freertos_system_calls)
        . = ALIGN(32);
        __syscalls_flash_end__ = .;
    } > CODEMEM

    .text :
    {
        __text = .;

        *(.text)
        *(.text*)
        *(.eh_frame)

        KEEP (*(.init))
        KEEP (*(.fini))

    } > CODEMEM

    _etext = .;
    PROVIDE(etext = .);

    __unprivileged_flash_end__ = .;

    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > CODEMEM

    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > CODEMEM
    __exidx_start = .;
    .ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } > CODEMEM
    __exidx_end = .;

    privileged_data :
    {
        . = ALIGN(32);
        __privileged_sram_start__ = .;
        *(privileged_data)
        . = ALIGN(32);
        __privileged_sram_end__ = .;
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
