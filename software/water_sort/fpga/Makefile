CROSS ?= riscv64-unknown-elf-
CC := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE := $(CROSS)size

ROOT := ../../..
BUILD_DIR := build
TARGET := water_sort_game
CFLAGS := -march=rv32i -mabi=ilp32 -mcmodel=medany -Os -ffreestanding \
	-msmall-data-limit=0 -fno-builtin -fno-jump-tables \
	-ffunction-sections -fdata-sections \
	-Wall -Wextra -Werror
LDFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
	-Wl,--gc-sections -Wl,-Map,$(BUILD_DIR)/$(TARGET).map -T linker.ld

ELF := $(BUILD_DIR)/$(TARGET).elf
I_BIN := $(BUILD_DIR)/$(TARGET)_i.bin
D_BIN := $(BUILD_DIR)/$(TARGET)_d.bin
I_MEM := $(BUILD_DIR)/$(TARGET)_i.mem
I_COE := $(ROOT)/coe/water_sort_game_i.coe
D_COE := $(ROOT)/coe/water_sort_game_d.coe

.PHONY: all clean size disasm

all: $(I_COE) $(D_COE) $(I_MEM) $(BUILD_DIR)/$(TARGET).asm size

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/startup.o: startup.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/isa_coverage.o: isa_coverage.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/game_main.o: game_main.c mmio.h ../water_sort.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -I.. -c $< -o $@

$(BUILD_DIR)/water_sort.o: ../water_sort.c ../water_sort.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -I.. -c $< -o $@

$(ELF): $(BUILD_DIR)/startup.o $(BUILD_DIR)/isa_coverage.o \
        $(BUILD_DIR)/game_main.o $(BUILD_DIR)/water_sort.o linker.ld
	$(CC) $(LDFLAGS) $(BUILD_DIR)/startup.o $(BUILD_DIR)/isa_coverage.o \
		$(BUILD_DIR)/game_main.o \
		$(BUILD_DIR)/water_sort.o -o $@

$(I_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@

$(D_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.rodata --only-section=.data \
		--change-addresses=-0x10000000 $< $@

$(I_MEM): $(I_BIN)
	hexdump -v -e '1/4 "%08x\n"' $< | \
		awk '{print} END {for (i=NR; i<1024; i++) print "00000013"}' > $@

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
