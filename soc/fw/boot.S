# Minimal RISC-V boot code for Ibex SoC
# Linker places this at 0x00000000 (reset vector)

.section .text.start
.global _start

_start:
    # Set stack pointer to top of SRAM (4KB)
    li sp, 0x00000FFC

    # Jump to C main
    jal ra, main

    # If main returns, write magic to SRAM and halt
_halt:
    li t0, 0xDEAD0000
    li t1, 0x00000110
    sw t0, 0(t1)
    j _halt
