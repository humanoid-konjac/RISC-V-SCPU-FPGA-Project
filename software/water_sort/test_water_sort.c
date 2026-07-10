#include <assert.h>
#include <stdio.h>

#include "water_sort.h"

static void clear_test_game(WaterSortGame *game)
{
    uint8_t tube_index;
    uint8_t layer;

    for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
        game->height[tube_index] = 0;
        for (layer = 0; layer < WATER_SORT_TUBE_CAPACITY; ++layer) {
            game->tube[tube_index][layer] = 0;
        }
    }
    game->cursor = 0;
    game->selected_source = WATER_SORT_NO_SELECTION;
    game->move_count = 0;
    game->finished = false;
}

static WaterSortConfirmResult pour(WaterSortGame *game, uint8_t source,
                                   uint8_t target)
{
    WaterSortConfirmResult result;

    game->cursor = source;
    result = water_sort_confirm(game);
    assert(result == WATER_SORT_CONFIRM_SELECTED);
    game->cursor = target;
    return water_sort_confirm(game);
}

static void test_reset_and_packing(void)
{
    WaterSortGame game;

    water_sort_reset(&game);
    assert(game.cursor == 0);
    assert(game.selected_source == WATER_SORT_NO_SELECTION);
    assert(game.move_count == 0);
    assert(!game.finished);
    assert(game.height[0] == 4);
    assert(game.height[6] == 0);
    assert(water_sort_pack_tube(&game, 0) == 0x2121u);
    assert(water_sort_pack_tube(&game, 5) == 0x5656u);
    assert(water_sort_pack_tube(&game, 8) == 0u);
}

static void test_cursor_and_selection(void)
{
    WaterSortGame game;

    water_sort_reset(&game);
    water_sort_move_cursor(&game, -1);
    assert(game.cursor == 7);
    water_sort_move_cursor(&game, 1);
    assert(game.cursor == 0);

    game.cursor = 6;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_INVALID);
    assert(game.selected_source == WATER_SORT_NO_SELECTION);

    game.cursor = 0;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_SELECTED);
    assert(game.selected_source == 0);
    water_sort_cancel(&game);
    assert(game.selected_source == WATER_SORT_NO_SELECTION);
}

static void test_invalid_target_keeps_selection(void)
{
    WaterSortGame game;

    water_sort_reset(&game);
    game.cursor = 0;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_SELECTED);

    game.cursor = 1;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_INVALID);
    assert(game.selected_source == 0);
    assert(game.move_count == 0);

    game.cursor = 0;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_INVALID);
    assert(game.selected_source == 0);
}

static void test_contiguous_and_capacity_limited_pours(void)
{
    WaterSortGame game;

    clear_test_game(&game);
    game.tube[0][0] = 1;
    game.tube[0][1] = 2;
    game.tube[0][2] = 2;
    game.tube[0][3] = 2;
    game.height[0] = 4;
    game.tube[1][0] = 3;
    game.tube[1][1] = 3;
    game.tube[1][2] = 2;
    game.height[1] = 3;

    assert(pour(&game, 0, 1) == WATER_SORT_CONFIRM_MOVED);
    assert(game.height[0] == 3);
    assert(game.height[1] == 4);
    assert(game.tube[0][2] == 2);
    assert(game.tube[0][3] == 0);
    assert(game.tube[1][3] == 2);
    assert(game.move_count == 1);

    clear_test_game(&game);
    game.tube[0][0] = 1;
    game.tube[0][1] = 2;
    game.tube[0][2] = 2;
    game.height[0] = 3;
    assert(pour(&game, 0, 1) == WATER_SORT_CONFIRM_MOVED);
    assert(game.height[0] == 1);
    assert(game.height[1] == 2);
    assert(game.tube[1][0] == 2);
    assert(game.tube[1][1] == 2);
}

static void test_known_solution(void)
{
    static const uint8_t moves[][2] = {
        {0, 6}, {1, 0}, {1, 6}, {0, 1}, {0, 6}, {1, 0}, {1, 6},
        {2, 1}, {3, 2}, {3, 1}, {2, 3}, {2, 1}, {3, 2}, {1, 3},
        {4, 1}, {5, 4}, {5, 1}, {4, 5}, {4, 1}, {5, 4}, {1, 5}
    };
    WaterSortGame game;
    unsigned move_index;

    water_sort_reset(&game);
    for (move_index = 0; move_index < sizeof(moves) / sizeof(moves[0]);
         ++move_index) {
        WaterSortConfirmResult result =
            pour(&game, moves[move_index][0], moves[move_index][1]);
        if (move_index + 1 == sizeof(moves) / sizeof(moves[0])) {
            assert(result == WATER_SORT_CONFIRM_WON);
        } else {
            assert(result == WATER_SORT_CONFIRM_MOVED);
        }
    }

    assert(game.finished);
    assert(water_sort_is_solved(&game));
    assert(game.move_count == 21);
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_INVALID);
    water_sort_move_cursor(&game, 1);
    assert(game.cursor == 5);

    water_sort_reset(&game);
    assert(!game.finished);
    assert(game.move_count == 0);
}

int main(void)
{
    test_reset_and_packing();
    test_cursor_and_selection();
    test_invalid_target_keeps_selection();
    test_contiguous_and_capacity_limited_pours();
    test_known_solution();
    puts("PASS: water_sort host tests");
    return 0;
}
