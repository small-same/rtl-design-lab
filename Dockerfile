FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    iverilog verilator yosys make git ca-certificates \
    gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
    && rm -rf /var/lib/apt/lists/*
# Create riscv32 symlinks (Ubuntu packages provide riscv64 but PicoRV32 uses -march=rv32i)
RUN for tool in gcc objcopy objdump ld as ar ranlib; do \
        ln -sf /usr/bin/riscv64-unknown-elf-$tool /usr/local/bin/riscv32-unknown-elf-$tool; \
    done
WORKDIR /workspace
