CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
BUILD_DIR := build

.PHONY: all test levels run clean

all: $(BUILD_DIR)/water_sort_cli $(BUILD_DIR)/test_water_sort

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/water_sort_cli: water_sort.c water_sort.h level_catalog.h main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) water_sort.c main.c -o $@

$(BUILD_DIR)/test_water_sort: water_sort.c water_sort.h level_catalog.h test_water_sort.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) water_sort.c test_water_sort.c -o $@

test: $(BUILD_DIR)/test_water_sort
	python3 tools/generate_levels.py --check
	./$(BUILD_DIR)/test_water_sort

levels:
	python3 tools/generate_levels.py

run: $(BUILD_DIR)/water_sort_cli
	./$(BUILD_DIR)/water_sort_cli

clean:
	rm -rf $(BUILD_DIR)
