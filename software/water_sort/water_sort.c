#include "water_sort.h"

static void clear_game(WaterSortGame *game)
{
    uint8_t tube_index;
    uint8_t layer;

    for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
        game->height[tube_index] = 0;
        for (layer = 0; layer < WATER_SORT_TUBE_CAPACITY; ++layer) {
            game->tube[tube_index][layer] = 0;
        }
    }
}

static void set_full_tube(WaterSortGame *game, uint8_t tube_index,
                          uint8_t layer0, uint8_t layer1,
                          uint8_t layer2, uint8_t layer3)
{
    game->tube[tube_index][0] = layer0;
    game->tube[tube_index][1] = layer1;
    game->tube[tube_index][2] = layer2;
    game->tube[tube_index][3] = layer3;
    game->height[tube_index] = WATER_SORT_TUBE_CAPACITY;
}

void water_sort_reset(WaterSortGame *game)
{
    clear_game(game);

    set_full_tube(game, 0, 1, 2, 1, 2);
    set_full_tube(game, 1, 2, 1, 2, 1);
    set_full_tube(game, 2, 3, 4, 3, 4);
    set_full_tube(game, 3, 4, 3, 4, 3);
    set_full_tube(game, 4, 5, 6, 5, 6);
    set_full_tube(game, 5, 6, 5, 6, 5);

    game->cursor = 0;
    game->selected_source = WATER_SORT_NO_SELECTION;
    game->move_count = 0;
    game->finished = false;
}

void water_sort_move_cursor(WaterSortGame *game, int direction)
{
    if (game->finished || direction == 0) {
        return;
    }

    if (direction < 0) {
        if (game->cursor == 0) {
            game->cursor = WATER_SORT_TUBE_COUNT - 1;
        } else {
            --game->cursor;
        }
    } else {
        ++game->cursor;
        if (game->cursor == WATER_SORT_TUBE_COUNT) {
            game->cursor = 0;
        }
    }
}

void water_sort_cancel(WaterSortGame *game)
{
    if (!game->finished) {
        game->selected_source = WATER_SORT_NO_SELECTION;
    }
}

bool water_sort_is_solved(const WaterSortGame *game)
{
    uint8_t tube_index;
    uint8_t layer;

    for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
        if (game->height[tube_index] == 0) {
            continue;
        }
        if (game->height[tube_index] != WATER_SORT_TUBE_CAPACITY) {
            return false;
        }
        for (layer = 1; layer < WATER_SORT_TUBE_CAPACITY; ++layer) {
            if (game->tube[tube_index][layer] != game->tube[tube_index][0]) {
                return false;
            }
        }
    }
    return true;
}

WaterSortConfirmResult water_sort_confirm(WaterSortGame *game)
{
    uint8_t source;
    uint8_t target;
    uint8_t color;
    uint8_t run_length;
    uint8_t free_space;
    uint8_t move_amount;
    uint8_t moved;

    if (game->finished) {
        return WATER_SORT_CONFIRM_INVALID;
    }

    target = game->cursor;
    if (game->selected_source == WATER_SORT_NO_SELECTION) {
        if (game->height[target] == 0) {
            return WATER_SORT_CONFIRM_INVALID;
        }
        game->selected_source = target;
        return WATER_SORT_CONFIRM_SELECTED;
    }

    source = game->selected_source;
    if (source == target || game->height[source] == 0 ||
        game->height[target] == WATER_SORT_TUBE_CAPACITY) {
        return WATER_SORT_CONFIRM_INVALID;
    }

    color = game->tube[source][game->height[source] - 1];
    if (game->height[target] != 0 &&
        game->tube[target][game->height[target] - 1] != color) {
        return WATER_SORT_CONFIRM_INVALID;
    }

    run_length = 1;
    while (run_length < game->height[source] &&
           game->tube[source][game->height[source] - run_length - 1] == color) {
        ++run_length;
    }

    free_space = WATER_SORT_TUBE_CAPACITY - game->height[target];
    move_amount = run_length < free_space ? run_length : free_space;

    for (moved = 0; moved < move_amount; ++moved) {
        --game->height[source];
        game->tube[source][game->height[source]] = 0;
        game->tube[target][game->height[target]] = color;
        ++game->height[target];
    }

    ++game->move_count;
    game->selected_source = WATER_SORT_NO_SELECTION;
    game->finished = water_sort_is_solved(game);

    return game->finished ? WATER_SORT_CONFIRM_WON : WATER_SORT_CONFIRM_MOVED;
}

uint32_t water_sort_pack_tube(const WaterSortGame *game, uint8_t tube_index)
{
    uint32_t packed = 0;
    uint8_t layer;

    if (tube_index >= WATER_SORT_TUBE_COUNT) {
        return 0;
    }

    for (layer = 0; layer < WATER_SORT_TUBE_CAPACITY; ++layer) {
        packed |= (uint32_t)(game->tube[tube_index][layer] & 0x0f)
                  << (layer * 4);
    }
    return packed;
}
