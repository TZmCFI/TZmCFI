MEMORY
{
    CODEMEM (rx) : ORIGIN = 0x00200000, LENGTH = 512K
    SRAM (rwx) : ORIGIN = 0x28200000, LENGTH = 32K

    SECURE_CODEMEM (rx) : ORIGIN = 0x10000000, LENGTH = 512K
    SECURE_SRAM (rwx) : ORIGIN = 0x38000000, LENGTH = 32K
}

ENTRY(HandleReset)

SECTIONS
{
    .text.isr_vector :
    {
        . = ALIGN(4);
        *(.text.isr_vector*);
        KEEP(*(.text.isr_vector*))
        . = ALIGN(4);
    } > CODEMEM

    .text :
    {
        __text = .;

        *(.text)
        *(.text*)
        *(.glue_7)         /* glue arm to thumb code */
        *(.glue_7t)        /* glue thumb to arm code */
        *(.eh_frame)

        KEEP (*(.init))
        KEEP (*(.fini))

    } > CODEMEM

    _etext = .;
    PROVIDE(etext = .);

    .rodata :
    {
        *(.rodata)
    } > CODEMEM

    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) }
    __exidx_start = .;
    .ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) }
    __exidx_end = .;

    __idata_start = .;
    .data : AT (__idata_start)
    {
        __data_start = .;
        *(.data)
        *(.data.*)
    } > SRAM
    __idata_end = __idata_start + SIZEOF(.data);
    _edata = .;
    PROVIDE(edata = .);

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
    . = . + 0x4000;
    PROVIDE(_MainStackTop = .);

    _end = .;
    PROVIDE(end = .);
}
