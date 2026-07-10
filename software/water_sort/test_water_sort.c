#include "water_sort.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void verify_level(WaterSortDifficulty difficulty, uint8_t level)
{
    WaterSortGame a;
    WaterSortGame b;
    uint8_t counts[WATER_SORT_MAX_COLORS + 1] = {0};
    uint8_t expected_colors = difficulty == WATER_SORT_EASY ? 4 :
                              difficulty == WATER_SORT_HARD ? 7 : 6;
    uint8_t expected_tubes = expected_colors +
                             (difficulty == WATER_SORT_EASY ? 2 : 1);
    uint8_t empty = 0;
    uint8_t mixed = 0;
    uint8_t tube;
    uint8_t layer;

    water_sort_start(&a, difficulty, level);
    water_sort_start(&b, difficulty, level);
    assert(memcmp(a.tube, b.tube, sizeof(a.tube)) == 0);
    assert(a.tube_count == expected_tubes);
    assert(a.color_count == expected_colors);
    assert(a.level == level);
    assert(water_sort_level_min_moves(difficulty, level) != 0);
    assert(!a.finished && !water_sort_is_solved(&a));
    for (tube = 0; tube < a.tube_count; ++tube) {
        if (a.height[tube] == 0) {
            ++empty;
            continue;
        }
        assert(a.height[tube] == 4);
        for (layer = 0; layer < 4; ++layer)
            ++counts[a.tube[tube][layer]];
        if (a.tube[tube][0] != a.tube[tube][1] ||
            a.tube[tube][1] != a.tube[tube][2] ||
            a.tube[tube][2] != a.tube[tube][3])
            ++mixed;
    }
    assert(empty == (difficulty == WATER_SORT_EASY ? 2 : 1));
    assert(mixed >= (difficulty == WATER_SORT_EASY ? 3 :
                     difficulty == WATER_SORT_NORMAL ? 5 : 6));
    for (tube = 1; tube <= expected_colors; ++tube)
        assert(counts[tube] == 4);
    for (tube = expected_tubes; tube < WATER_SORT_MAX_TUBES; ++tube)
        assert(a.height[tube] == 0 && water_sort_pack_tube(&a, tube) == 0);
}

static int make_first_legal_move(WaterSortGame *game)
{
    uint8_t source;
    uint8_t target;
    for (source = 0; source < game->tube_count; ++source) {
        for (target = 0; target < game->tube_count; ++target) {
            WaterSortConfirmResult result;
            WaterSortGame before = *game;
            game->cursor = source;
            if (water_sort_confirm(game) != WATER_SORT_CONFIRM_SELECTED) {
                *game = before;
                continue;
            }
            game->cursor = target;
            result = water_sort_confirm(game);
            if (result == WATER_SORT_CONFIRM_MOVED ||
                result == WATER_SORT_CONFIRM_WON)
                return 1;
            *game = before;
        }
    }
    return 0;
}

static void test_generation(void)
{
    uint8_t level;
    int difficulty;
    for (difficulty = WATER_SORT_EASY; difficulty <= WATER_SORT_HARD;
         ++difficulty) {
        WaterSortGame previous;
        for (level = 0; level < WATER_SORT_LEVEL_COUNT; ++level) {
            WaterSortGame current;
            verify_level((WaterSortDifficulty)difficulty, level);
            water_sort_start(&current, (WaterSortDifficulty)difficulty, level);
            if (level != 0)
                assert(memcmp(current.tube, previous.tube,
                              sizeof(current.tube)) != 0);
            previous = current;
        }
    }
}

static void test_cursor_restart_and_undo(void)
{
    WaterSortGame game;
    WaterSortGame initial;
    unsigned moves = 0;

    water_sort_start(&game, WATER_SORT_HARD, 11);
    initial = game;
    water_sort_move_cursor(&game, -1);
    assert(game.cursor == game.tube_count - 1);
    water_sort_move_cursor(&game, 1);
    assert(game.cursor == 0);
    while (moves < 32 && make_first_legal_move(&game))
        ++moves;
    assert(moves != 0);
    assert(game.history_length == moves && game.move_count == moves);
    while (water_sort_undo(&game))
        ;
    assert(game.move_count == 0 && game.history_length == 0);
    assert(memcmp(game.tube, initial.tube, sizeof(game.tube)) == 0);
    assert(memcmp(game.height, initial.height, sizeof(game.height)) == 0);
    assert(!water_sort_undo(&game));

    (void)make_first_legal_move(&game);
    water_sort_restart(&game);
    assert(memcmp(game.tube, initial.tube, sizeof(game.tube)) == 0);
    assert(game.move_count == 0 && game.history_length == 0);
}

static void test_history_full(void)
{
    WaterSortGame game;
    uint8_t source;
    uint8_t target;
    water_sort_start(&game, WATER_SORT_EASY, 7);
    for (source = 0; source < game.tube_count && game.height[source] == 0;
         ++source)
        ;
    for (target = 0; target < game.tube_count && game.height[target] != 0;
         ++target)
        ;
    assert(source < game.tube_count && target < game.tube_count);
    game.cursor = source;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_SELECTED);
    game.cursor = target;
    game.history_length = WATER_SORT_HISTORY_CAPACITY;
    assert(water_sort_confirm(&game) == WATER_SORT_CONFIRM_HISTORY_FULL);
    assert(game.history_full && game.move_count == 0);
}

int main(void)
{
    test_generation();
    test_cursor_restart_and_undo();
    test_history_full();
    puts("water_sort tests passed (36 solver-verified levels)");
    return 0;
}
