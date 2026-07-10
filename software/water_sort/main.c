#include "water_sort.h"

#include <stdio.h>

static void print_game(const WaterSortGame *game)
{
    int layer;
    uint8_t tube;
    for (layer = 3; layer >= 0; --layer) {
        for (tube = 0; tube < game->tube_count; ++tube)
            printf(" %u ", game->tube[tube][layer]);
        putchar('\n');
    }
    for (tube = 0; tube < game->tube_count; ++tube)
        printf(game->cursor == tube ? " ^ " : "   ");
    printf("\nseed=%u moves=%u\n", (unsigned)game->seed,
           (unsigned)game->move_count);
}

int main(void)
{
    WaterSortGame game;
    int command;
    water_sort_start(&game, WATER_SORT_NORMAL, 1);
    puts("a/d move, e confirm, c cancel, u undo, r restart, q quit");
    for (;;) {
        print_game(&game);
        command = getchar();
        if (command == EOF || command == 'q')
            break;
        if (command == 'a') water_sort_move_cursor(&game, -1);
        if (command == 'd') water_sort_move_cursor(&game, 1);
        if (command == 'e') (void)water_sort_confirm(&game);
        if (command == 'c') water_sort_cancel(&game);
        if (command == 'u') (void)water_sort_undo(&game);
        if (command == 'r') water_sort_restart(&game);
    }
    return 0;
}
