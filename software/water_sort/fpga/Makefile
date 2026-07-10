CROSS ?= riscv64-unknown-elf-
CC := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE := $(CROSS)size

ROOT := ../../..
BUILD_DIR := build
TARGET := game_phase3
CFLAGS := -march=rv32i -mabi=ilp32 -mcmodel=medany -Os -ffreestanding \
	-msmall-data-limit=0 -fno-builtin -fno-jump-tables \
	-ffunction-sections -fdata-sections \
	-Wall -Wextra -Werror
LDFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
	-Wl,--gc-sections -Wl,-Map,$(BUILD_DIR)/$(TARGET).map -T linker.ld

ELF := $(BUILD_DIR)/$(TARGET).elf
I_BIN := $(BUILD_DIR)/$(TARGET)_i.bin
D_BIN := $(BUILD_DIR)/$(TARGET)_d.bin
I_COE := $(ROOT)/coe/game_phase3_i.coe
D_COE := $(ROOT)/coe/game_phase3_d.coe

.PHONY: all clean size disasm

all: $(I_COE) $(D_COE) $(BUILD_DIR)/$(TARGET).asm size

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/startup.o: startup.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/phase3_main.o: phase3_main.c mmio.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(BUILD_DIR)/startup.o $(BUILD_DIR)/phase3_main.o linker.ld
	$(CC) $(LDFLAGS) $(BUILD_DIR)/startup.o $(BUILD_DIR)/phase3_main.o -o $@

$(I_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@

$(D_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.rodata --only-section=.data \
		--change-addresses=-0x10000000 $< $@

$(I_COE): $(I_BIN)
	{ printf 'MEMORY_INITIALIZATION_RADIX=16;\nMEMORY_INITIALIZATION_VECTOR=\n'; \
	  hexdump -v -e '1/4 "%08x\n"' $< | \
	  awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}'; } > $@

$(D_COE): $(D_BIN)
	{ printf 'MEMORY_INITIALIZATION_RADIX=16;\nMEMORY_INITIALIZATION_VECTOR=\n'; \
	  if test -s $<; then \
	    hexdump -v -e '1/4 "%08x\n"' $< | \
	    awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}'; \
	  else printf '00000000;\n'; fi; } > $@

$(BUILD_DIR)/$(TARGET).asm: $(ELF)
	$(OBJDUMP) -D -M no-aliases $< > $@

size: $(ELF)
	$(SIZE) -A $<

disasm: $(BUILD_DIR)/$(TARGET).asm

clean:
	rm -rf $(BUILD_DIR) $(I_COE) $(D_COE)
