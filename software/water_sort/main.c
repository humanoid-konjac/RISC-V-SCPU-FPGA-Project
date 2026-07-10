#include <stdio.h>

#include "water_sort.h"

static char color_symbol(uint8_t color)
{
    static const char symbols[] = ".RGBYPC";

    if (color > WATER_SORT_COLOR_COUNT) {
        return '?';
    }
    return symbols[color];
}

static void draw_game(const WaterSortGame *game)
{
    int layer;
    uint8_t tube_index;

    puts("");
    for (layer = WATER_SORT_TUBE_CAPACITY - 1; layer >= 0; --layer) {
        for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
            printf("|%c| ", color_symbol(game->tube[tube_index][layer]));
        }
        putchar('\n');
    }
    for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
        printf(" %u  ", (unsigned)tube_index);
    }
    putchar('\n');
    for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
        printf(game->cursor == tube_index ? " ^  " : "    ");
    }
    putchar('\n');

    printf("moves=%u  selected=", (unsigned)game->move_count);
    if (game->selected_source == WATER_SORT_NO_SELECTION) {
        puts("none");
    } else {
        printf("%u\n", (unsigned)game->selected_source);
    }
    if (game->finished) {
        puts("Solved! Press r to restart or q to quit.");
    }
}

int main(void)
{
    WaterSortGame game;
    char line[32];

    water_sort_reset(&game);
    puts("Water Sort host test: a=left, d=right, e=confirm, x=cancel, r=restart, q=quit");

    for (;;) {
        draw_game(&game);
        fputs("> ", stdout);
        if (fgets(line, sizeof(line), stdin) == NULL || line[0] == 'q') {
            break;
        }

        switch (line[0]) {
        case 'a':
            water_sort_move_cursor(&game, -1);
            break;
        case 'd':
            water_sort_move_cursor(&game, 1);
            break;
        case 'e':
            (void)water_sort_confirm(&game);
            break;
        case 'x':
            water_sort_cancel(&game);
            break;
        case 'r':
            water_sort_reset(&game);
            break;
        default:
            puts("Unknown command.");
            break;
        }
    }

    return 0;
}
