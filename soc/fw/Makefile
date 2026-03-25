# Firmware build for Ibex SoC
# Requires riscv32-unknown-elf toolchain (installed in Docker)

CROSS    := riscv32-unknown-elf-
CC       := $(CROSS)gcc
OBJCOPY  := $(CROSS)objcopy
OBJDUMP  := $(CROSS)objdump

CFLAGS   := -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostdlib
LDFLAGS  := -T link.ld -nostdlib -Wl,--no-relax

SRCS_S   := boot.S
SRCS_C   := main.c
OBJS     := boot.o main.o

TARGET   := firmware

all: $(TARGET).hex

$(TARGET).elf: $(OBJS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@

disasm: $(TARGET).elf
	$(OBJDUMP) -d $<

clean:
	rm -f *.o *.elf *.bin *.hex

.PHONY: all clean disasm
