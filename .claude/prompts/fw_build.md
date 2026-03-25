# Build Firmware

Compile the RISC-V RV32IMC firmware for the SoC.

## Usage

```
/fw_build
```

## What It Does

1. Spawns a **lint-synthesis-agent** (model: haiku)
2. Executes: `docker compose run --rm eda make -C soc/fw`
3. Compiles firmware source files:
   - `soc/fw/boot.S` — Boot/startup assembly
   - `soc/fw/main.c` — Main application code
   - `soc/fw/link.ld` — Linker script
4. Outputs: compiled binary for loading into `axi_sram` (address `0x0000_0000`)
5. Reports: build success/failure, binary size, any compiler warnings

## Notes

- Requires Docker Desktop to be running (RISC-V toolchain is inside the container)
- The firmware is compiled with the RISC-V GCC cross-compiler targeting RV32IMC
- The linker script maps code and data to the SoC address map (SRAM at `0x0000_0000`)
- After building, run SoC-level sim to verify: `/run_step sim soc`
- To modify firmware, edit files in `soc/fw/` then re-run `/fw_build`
