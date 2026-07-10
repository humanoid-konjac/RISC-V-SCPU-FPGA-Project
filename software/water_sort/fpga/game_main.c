#include <stdbool.h>
#include <stdint.h>

#include "mmio.h"
#include "water_sort.h"

static WaterSortGame game;
static bool playing;
static bool level_editing;
static bool input_error;
static uint8_t level_entry;

static uint16_t pack_moves_bcd(uint16_t value)
{
    uint16_t packed = 0;
    uint16_t power = 1000;
    int position;
    for (position = 3; position >= 0; --position) {
        uint16_t digit = 0;
        while (value >= power) {
            value = (uint16_t)(value - power);
            ++digit;
        }
        packed |= (uint16_t)(digit << (position * 4));
        power = (uint16_t)(power == 1000 ? 100 :
                           power == 100 ? 10 : 1);
    }
    return packed;
}

static uint32_t pack_level_bcd(uint8_t value)
{
    uint8_t tens = 0;
    while (value >= 10) {
        value = (uint8_t)(value - 10);
        ++tens;
    }
    return ((uint32_t)tens << 4) | value;
}

static uint32_t pack_ui_state(void)
{
    uint32_t ui = (uint32_t)game.cursor & GAME_UI_CURSOR_MASK;
    if (game.selected_source != WATER_SORT_NO_SELECTION) {
        ui |= (uint32_t)game.selected_source << GAME_UI_SELECTED_SHIFT;
        ui |= GAME_UI_SELECTED_VALID;
    }
    if (game.finished)
        ui |= GAME_UI_FINISHED;
    if (playing)
        ui |= GAME_UI_PLAYING;
    if (game.history_full)
        ui |= GAME_UI_HISTORY_FULL;
    if (input_error)
        ui |= GAME_UI_INPUT_ERROR;
    return ui;
}

static void publish_state(void)
{
    uint8_t tube;
    uint32_t meta;

    for (tube = 0; tube < WATER_SORT_MAX_TUBES; ++tube)
        GAME_TUBE(tube) = playing ? water_sort_pack_tube(&game, tube) : 0;
    meta = (uint32_t)game.difficulty |
           ((uint32_t)game.tube_count << 4) |
           ((uint32_t)pack_moves_bcd(game.move_count) << 16);
    GAME_UI = pack_ui_state();
    GAME_MOVE_COUNT = game.move_count;
    GAME_META = meta;
    GAME_LEVEL = pack_level_bcd(playing ? (uint8_t)(game.level + 1)
                                          : level_entry);
    GAME_COMMIT = 1;

    SEVEN_SEG_DATA = playing ? game.move_count : level_entry;
    LED_DATA = playing ? (game.finished ? 0x0000ffffu :
                           (1u << game.cursor))
                       : (1u << game.difficulty);
}

static void cycle_difficulty(int direction)
{
    WaterSortDifficulty next = game.difficulty;
    if (direction < 0)
        next = next == WATER_SORT_EASY ? WATER_SORT_HARD :
               (WaterSortDifficulty)(next - 1);
    else
        next = next == WATER_SORT_HARD ? WATER_SORT_EASY :
               (WaterSortDifficulty)(next + 1);
    water_sort_start(&game, next, game.level);
}

static void cycle_level(int direction)
{
    uint8_t next = game.level;
    if (direction < 0)
        next = next == 0 ? WATER_SORT_LEVEL_COUNT - 1 : next - 1;
    else
        next = next + 1 == WATER_SORT_LEVEL_COUNT ? 0 : next + 1;
    water_sort_start(&game, game.difficulty, next);
    level_entry = (uint8_t)(next + 1);
    level_editing = false;
    input_error = false;
}

static void apply_level_entry(void)
{
    input_error = level_entry == 0 || level_entry > WATER_SORT_LEVEL_COUNT;
    if (!input_error)
        water_sort_start(&game, game.difficulty,
                         (uint8_t)(level_entry - 1));
}

static void append_level_digit(uint8_t digit)
{
    uint16_t candidate;
    if (!level_editing) {
        level_entry = 0;
        level_editing = true;
    }
    candidate = (uint16_t)((level_entry << 3) + (level_entry << 1) + digit);
    if (candidate > 99) {
        input_error = true;
        return;
    }
    level_entry = (uint8_t)candidate;
    apply_level_entry();
}

static void erase_level_digit(void)
{
    uint8_t quotient = 0;
    uint8_t value = level_entry;
    while (value >= 10) {
        value = (uint8_t)(value - 10);
        ++quotient;
    }
    level_entry = quotient;
    level_editing = true;
    apply_level_entry();
}

static void handle_menu_event(uint32_t event)
{
    if (event == KEY_EVENT_LEFT)
        cycle_level(-1);
    else if (event == KEY_EVENT_RIGHT)
        cycle_level(1);
    else if (event == KEY_EVENT_UP)
        cycle_difficulty(-1);
    else if (event == KEY_EVENT_DOWN)
        cycle_difficulty(1);
    else if (event == KEY_EVENT_BACKSPACE)
        erase_level_digit();
    else if (event >= KEY_EVENT_DIGIT0 &&
             event < KEY_EVENT_DIGIT0 + 10u)
        append_level_digit((uint8_t)(event - KEY_EVENT_DIGIT0));
    else if (event == KEY_EVENT_CONFIRM && !input_error) {
        water_sort_start(&game, game.difficulty, game.level);
        playing = true;
        level_editing = false;
    }
}

static void handle_game_event(uint32_t event)
{
    if (event == KEY_EVENT_LEFT)
        water_sort_move_cursor(&game, -1);
    else if (event == KEY_EVENT_RIGHT)
        water_sort_move_cursor(&game, 1);
    else if (event == KEY_EVENT_CONFIRM)
        (void)water_sort_confirm(&game);
    else if (event == KEY_EVENT_CANCEL)
        water_sort_cancel(&game);
    else if (event == KEY_EVENT_UNDO)
        (void)water_sort_undo(&game);
    else if (event == KEY_EVENT_RESTART)
        water_sort_restart(&game);
    else if (event == KEY_EVENT_MENU) {
        playing = false;
        level_editing = false;
        level_entry = (uint8_t)(game.level + 1);
        input_error = false;
        water_sort_cancel(&game);
    }
}

int main(void)
{
    water_sort_start(&game, WATER_SORT_NORMAL, 0);
    playing = false;
    level_editing = false;
    input_error = false;
    level_entry = 1;
    publish_state();
    for (;;) {
        if ((KEY_STATUS & 1u) != 0u) {
            uint32_t event = KEY_CODE;
            if (playing)
                handle_game_event(event);
            else
                handle_menu_event(event);
            publish_state();
            KEY_ACK = 1;
        }
    }
}
