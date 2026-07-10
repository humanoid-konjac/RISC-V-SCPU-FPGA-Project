#include <stdint.h>

#include "mmio.h"
#include "water_sort.h"

static WaterSortGame game;

static uint32_t pack_ui_state(void)
{
    uint32_t ui = (uint32_t)game.cursor & GAME_UI_CURSOR_MASK;

    if (game.selected_source != WATER_SORT_NO_SELECTION) {
        ui |= (uint32_t)game.selected_source << GAME_UI_SELECTED_SHIFT;
        ui |= GAME_UI_SELECTED_VALID;
    }
    if (game.finished) {
        ui |= GAME_UI_FINISHED;
    }
    return ui;
}

static void publish_game_state(void)
{
    uint8_t tube_index;

    for (tube_index = 0; tube_index < WATER_SORT_TUBE_COUNT; ++tube_index) {
        GAME_TUBE(tube_index) = water_sort_pack_tube(&game, tube_index);
    }
    GAME_UI = pack_ui_state();
    GAME_MOVE_COUNT = game.move_count;
    GAME_COMMIT = 1;

    SEVEN_SEG_DATA = game.move_count;
    LED_DATA = game.finished ? 0x0000ffffu : (1u << game.cursor);
}

static void handle_key_event(uint32_t event)
{
    if (event == KEY_EVENT_LEFT) {
        water_sort_move_cursor(&game, -1);
    } else if (event == KEY_EVENT_RIGHT) {
        water_sort_move_cursor(&game, 1);
    } else if (event == KEY_EVENT_CONFIRM) {
        (void)water_sort_confirm(&game);
    } else if (event == KEY_EVENT_CANCEL) {
        water_sort_cancel(&game);
    } else if (event == KEY_EVENT_RESTART) {
        water_sort_reset(&game);
    }
}

int main(void)
{
    water_sort_reset(&game);
    publish_game_state();

    for (;;) {
        if ((KEY_STATUS & 1u) != 0u) {
            handle_key_event(KEY_CODE);
            publish_game_state();
            KEY_ACK = 1;
        }
    }
}
