#ifndef WATER_SORT_H
#define WATER_SORT_H

#include <stdbool.h>
#include <stdint.h>

enum {
    WATER_SORT_TUBE_COUNT = 8,
    WATER_SORT_TUBE_CAPACITY = 4,
    WATER_SORT_COLOR_COUNT = 6,
    WATER_SORT_NO_SELECTION = 0xff
};

typedef enum {
    WATER_SORT_CONFIRM_INVALID = 0,
    WATER_SORT_CONFIRM_SELECTED,
    WATER_SORT_CONFIRM_MOVED,
    WATER_SORT_CONFIRM_WON
} WaterSortConfirmResult;

typedef struct {
    uint8_t tube[WATER_SORT_TUBE_COUNT][WATER_SORT_TUBE_CAPACITY];
    uint8_t height[WATER_SORT_TUBE_COUNT];
    uint8_t cursor;
    uint8_t selected_source;
    uint16_t move_count;
    bool finished;
} WaterSortGame;

void water_sort_reset(WaterSortGame *game);
void water_sort_move_cursor(WaterSortGame *game, int direction);
void water_sort_cancel(WaterSortGame *game);
WaterSortConfirmResult water_sort_confirm(WaterSortGame *game);
bool water_sort_is_solved(const WaterSortGame *game);
uint32_t water_sort_pack_tube(const WaterSortGame *game, uint8_t tube_index);

#endif
