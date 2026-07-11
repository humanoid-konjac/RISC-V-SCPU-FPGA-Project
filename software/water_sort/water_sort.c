#include "water_sort.h"
#include "level_catalog.h"

static void clear_board(WaterSortGame *game)
{
    uint8_t tube;
    uint8_t layer;

    for (tube = 0; tube < WATER_SORT_MAX_TUBES; ++tube) {
        game->height[tube] = 0;
        for (layer = 0; layer < WATER_SORT_TUBE_CAPACITY; ++layer)
            game->tube[tube][layer] = 0;
    }
}

static void set_configuration(WaterSortGame *game,
                              WaterSortDifficulty difficulty)
{
    if (difficulty > WATER_SORT_HARD)
        difficulty = WATER_SORT_NORMAL;
    game->difficulty = difficulty;
    if (difficulty == WATER_SORT_EASY) {
        game->color_count = 4;
        game->tube_count = 6;
    } else if (difficulty == WATER_SORT_HARD) {
        game->color_count = 7;
        game->tube_count = 8;
    } else {
        game->color_count = 6;
        game->tube_count = 7;
    }
}

static void load_level(WaterSortGame *game)
{
    uint8_t tube;
    clear_board(game);
    for (tube = 0; tube < game->tube_count; ++tube) {
        uint16_t packed = water_sort_level_catalog[game->difficulty]
                                                  [game->level][tube];
        uint8_t layer;
        for (layer = 0; layer < WATER_SORT_TUBE_CAPACITY; ++layer) {
            uint8_t color = (uint8_t)((packed >> (layer * 4)) & 15);
            game->tube[tube][layer] = color;
            if (color != 0)
                game->height[tube] = WATER_SORT_TUBE_CAPACITY;
        }
    }
}

void water_sort_start(WaterSortGame *game, WaterSortDifficulty difficulty,
                      uint8_t level)
{
    set_configuration(game, difficulty);
    game->level = level < WATER_SORT_LEVEL_COUNT ? level : 0;
    load_level(game);
    game->cursor = 0;
    game->selected_source = WATER_SORT_NO_SELECTION;
    game->move_count = 0;
    game->history_length = 0;
    game->finished = false;
    game->history_full = false;
}

void water_sort_restart(WaterSortGame *game)
{
    water_sort_start(game, game->difficulty, game->level);
}

uint8_t water_sort_level_min_moves(WaterSortDifficulty difficulty,
                                   uint8_t level)
{
    if (difficulty > WATER_SORT_HARD || level >= WATER_SORT_LEVEL_COUNT)
        return 0;
    return water_sort_level_solution_lengths[difficulty][level];
}

void water_sort_move_cursor(WaterSortGame *game, int direction)
{
    if (direction == 0 || game->tube_count == 0)
        return;
    if (direction < 0)
        game->cursor = game->cursor == 0 ? game->tube_count - 1
                                         : game->cursor - 1;
    else
        game->cursor = game->cursor + 1 == game->tube_count
                           ? 0 : game->cursor + 1;
}

void water_sort_cancel(WaterSortGame *game)
{
    game->selected_source = WATER_SORT_NO_SELECTION;
}

bool water_sort_is_solved(const WaterSortGame *game)
{
    uint8_t tube;
    uint8_t layer;

    for (tube = 0; tube < game->tube_count; ++tube) {
        if (game->height[tube] == 0)
            continue;
        if (game->height[tube] != WATER_SORT_TUBE_CAPACITY)
            return false;
        for (layer = 1; layer < WATER_SORT_TUBE_CAPACITY; ++layer) {
            if (game->tube[tube][layer] != game->tube[tube][0])
                return false;
        }
    }
    return true;
}

WaterSortConfirmResult water_sort_confirm(WaterSortGame *game)
{
    uint8_t source;
    uint8_t target = game->cursor;
    uint8_t color;
    uint8_t run_length;
    uint8_t free_space;
    uint8_t move_amount;
    uint8_t moved;

    if (game->finished)
        return WATER_SORT_CONFIRM_INVALID;
    if (game->selected_source == WATER_SORT_NO_SELECTION) {
        if (game->height[target] == 0)
            return WATER_SORT_CONFIRM_INVALID;
        game->selected_source = target;
        return WATER_SORT_CONFIRM_SELECTED;
    }

    source = game->selected_source;
    if (source == target || game->height[source] == 0 ||
        game->height[target] == WATER_SORT_TUBE_CAPACITY)
        return WATER_SORT_CONFIRM_INVALID;
    color = game->tube[source][game->height[source] - 1];
    if (game->height[target] != 0 &&
        game->tube[target][game->height[target] - 1] != color)
        return WATER_SORT_CONFIRM_INVALID;
    if (game->history_length == WATER_SORT_HISTORY_CAPACITY) {
        game->history_full = true;
        return WATER_SORT_CONFIRM_HISTORY_FULL;
    }

    run_length = 1;
    while (run_length < game->height[source] &&
           game->tube[source][game->height[source] - run_length - 1] == color)
        ++run_length;
    free_space = WATER_SORT_TUBE_CAPACITY - game->height[target];
    move_amount = run_length < free_space ? run_length : free_space;
    for (moved = 0; moved < move_amount; ++moved) {
        --game->height[source];
        game->tube[source][game->height[source]] = 0;
        game->tube[target][game->height[target]++] = color;
    }
    game->history[game->history_length++] =
        (uint8_t)((source << 5) | (target << 2) | (move_amount & 3));
    ++game->move_count;
    game->selected_source = WATER_SORT_NO_SELECTION;
    game->history_full = game->history_length == WATER_SORT_HISTORY_CAPACITY;
    game->finished = water_sort_is_solved(game);
    return game->finished ? WATER_SORT_CONFIRM_WON : WATER_SORT_CONFIRM_MOVED;
}

bool water_sort_undo(WaterSortGame *game)
{
    uint8_t entry;
    uint8_t source;
    uint8_t target;
    uint8_t amount;
    uint8_t color;
    uint8_t moved;

    if (game->history_length == 0)
        return false;
    entry = game->history[--game->history_length];
    source = entry >> 5;
    target = (entry >> 2) & 7;
    amount = entry & 3;
    if (amount == 0)
        amount = 4;
    color = game->tube[target][game->height[target] - 1];
    for (moved = 0; moved < amount; ++moved) {
        --game->height[target];
        game->tube[target][game->height[target]] = 0;
        game->tube[source][game->height[source]++] = color;
    }
    if (game->move_count != 0)
        --game->move_count;
    game->cursor = source;
    game->selected_source = WATER_SORT_NO_SELECTION;
    game->finished = false;
    game->history_full = false;
    return true;
}

uint32_t water_sort_pack_tube(const WaterSortGame *game, uint8_t tube_index)
{
    uint32_t packed = 0;
    uint8_t layer;
    if (tube_index >= game->tube_count)
        return 0;
    for (layer = 0; layer < WATER_SORT_TUBE_CAPACITY; ++layer)
        packed |= (uint32_t)(game->tube[tube_index][layer] & 15)
                  << (layer * 4);
    return packed;
}
