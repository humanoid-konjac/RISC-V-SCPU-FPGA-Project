#ifndef WATER_SORT_H
#define WATER_SORT_H

#include <stdbool.h>
#include <stdint.h>

enum {
    WATER_SORT_MAX_TUBES = 8,
    WATER_SORT_TUBE_CAPACITY = 4,
    WATER_SORT_MAX_COLORS = 7,
    WATER_SORT_LEVEL_COUNT = 12,
    WATER_SORT_NO_SELECTION = 0xff,
    WATER_SORT_HISTORY_CAPACITY = 2048
};

typedef enum {
    WATER_SORT_EASY = 0,
    WATER_SORT_NORMAL = 1,
    WATER_SORT_HARD = 2
} WaterSortDifficulty;

typedef enum {
    WATER_SORT_CONFIRM_INVALID = 0,
    WATER_SORT_CONFIRM_SELECTED,
    WATER_SORT_CONFIRM_MOVED,
    WATER_SORT_CONFIRM_WON,
    WATER_SORT_CONFIRM_HISTORY_FULL
} WaterSortConfirmResult;

typedef struct {
    uint8_t tube[WATER_SORT_MAX_TUBES][WATER_SORT_TUBE_CAPACITY];
    uint8_t height[WATER_SORT_MAX_TUBES];
    uint8_t history[WATER_SORT_HISTORY_CAPACITY];
    uint16_t move_count;
    uint16_t history_length;
    uint8_t cursor;
    uint8_t selected_source;
    uint8_t tube_count;
    uint8_t color_count;
    uint8_t level;
    WaterSortDifficulty difficulty;
    bool finished;
    bool history_full;
} WaterSortGame;

void water_sort_start(WaterSortGame *game, WaterSortDifficulty difficulty,
                      uint8_t level);
void water_sort_restart(WaterSortGame *game);
void water_sort_move_cursor(WaterSortGame *game, int direction);
void water_sort_cancel(WaterSortGame *game);
WaterSortConfirmResult water_sort_confirm(WaterSortGame *game);
bool water_sort_undo(WaterSortGame *game);
bool water_sort_is_solved(const WaterSortGame *game);
uint32_t water_sort_pack_tube(const WaterSortGame *game, uint8_t tube_index);
uint8_t water_sort_level_min_moves(WaterSortDifficulty difficulty,
                                   uint8_t level);

#endif
