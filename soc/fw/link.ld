/* Linker script for Ibex SoC — SRAM at 0x00000000, 4KB */

MEMORY
{
    SRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text.start)   /* boot code first */
        *(.text*)
    } > SRAM

    .rodata : {
        *(.rodata*)
    } > SRAM

    .data : {
        *(.data*)
    } > SRAM

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > SRAM

    /* Stack grows down from top of SRAM */
    _stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}
