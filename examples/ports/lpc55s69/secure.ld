MEMORY
{
    /* Flash memory */
    CODEMEM (rx) : ORIGIN = 0x10000000, LENGTH = 64K
    /* SRAM0 */
    SRAM (rwx) : ORIGIN = 0x30000000, LENGTH = 64K
}

ENTRY(handleReset)

SECTIONS
{
    .isr_vector :
    {
        . = ALIGN(4);
        *(.isr_vector*);
        KEEP(*(.isr_vector*))
        . = ALIGN(4);
    } > CODEMEM


    .gnu.sgstubs :
    {
        . = ALIGN(32);
        __nsc_start = .;
        KEEP(*(.gnu.sgstubs*))
        . = ALIGN(32);
        __nsc_end = .;
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

    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > CODEMEM

    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > CODEMEM
    __exidx_start = .;
    .ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } > CODEMEM
    __exidx_end = .;

    . = ALIGN(4);

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
    PROVIDE(_main_stack_limit = .);
    . = . + 0x400;
    PROVIDE(_main_stack_top = .);

    /* Reserve stack space */
    . = ALIGN(8);
    PROVIDE(_handler_stack_limit = .);
    . = . + 0x400;
    PROVIDE(_handler_stack_top = .);

    _end = .;
    PROVIDE(end = .);
}
