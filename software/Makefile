PYTHON ?= python3
CROSS ?= riscv64-elf-

CC := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf
SIZE := $(CROSS)size

SOURCE := voice_game.c
STARTUP := start.S
LINKER := linker.ld
ELF := voice_game.elf
BIN := voice_game.bin
HEX := voice_game.hex
LISTING := voice_game.lst
MAP := voice_game.map
COE := ../coe/voice_game.coe

CFLAGS := -march=rv32i -mabi=ilp32 -Os -ffreestanding -fno-builtin \
	-fno-common -fno-pic -fno-pie -fno-stack-protector \
	-fomit-frame-pointer -ffunction-sections -fdata-sections \
	-mstrict-align -mno-relax -msmall-data-limit=0 \
	-Wall -Wextra -Werror
LDFLAGS := -nostdlib -nostartfiles -static -no-pie \
	-Wl,--gc-sections -Wl,--no-relax -Wl,-Map=$(MAP) -T $(LINKER)

.PHONY: all clean
all: $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $(ELF) $(BIN)
	$(PYTHON) elf_to_rom.py $(BIN) --hex $(HEX) --coe $(COE) --depth 1024
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(LISTING)
	$(PYTHON) audit_rv32i.py $(ELF) --objdump $(OBJDUMP) --readelf $(READELF)
	$(SIZE) $(ELF)

$(ELF): $(SOURCE) $(STARTUP) $(LINKER)
	$(CC) $(CFLAGS) $(STARTUP) $(SOURCE) $(LDFLAGS) -o $@

clean:
	rm -f $(ELF) $(BIN) $(HEX) $(LISTING) $(MAP) $(COE)
