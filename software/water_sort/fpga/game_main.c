#include <stdbool.h>
#include <stdint.h>

#include "mmio.h"
#include "water_sort.h"

static WaterSortGame game;
static bool playing;
static bool seed_editing;
static bool input_error;

static uint32_t seed_random(void)
{
    uint32_t first = RANDOM_COUNTER;
    uint32_t second = RANDOM_COUNTER;
    return first ^ (second << 7) ^ (second >> 9) ^ 0xa5a5c3c3u;
}

static void pack_seed_bcd(uint32_t value, uint32_t *low, uint32_t *high)
{
    static const uint32_t powers[10] = {
        1u, 10u, 100u, 1000u, 10000u, 100000u, 1000000u,
        10000000u, 100000000u, 1000000000u
    };
    int position;
    *low = 0;
    *high = 0;
    for (position = 9; position >= 0; --position) {
        uint32_t digit = 0;
        while (value >= powers[position]) {
            value -= powers[position];
            ++digit;
        }
        if (position < 8)
            *low |= digit << (position * 4);
        else
            *high |= digit << ((position - 8) * 4);
    }
}

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
    uint32_t seed_lo;
    uint32_t seed_hi;
    uint32_t meta;

    for (tube = 0; tube < WATER_SORT_MAX_TUBES; ++tube)
        GAME_TUBE(tube) = playing ? water_sort_pack_tube(&game, tube) : 0;
    pack_seed_bcd(game.seed, &seed_lo, &seed_hi);
    meta = (uint32_t)game.difficulty |
           ((uint32_t)game.tube_count << 4) |
           ((uint32_t)pack_moves_bcd(game.move_count) << 16);
    GAME_UI = pack_ui_state();
    GAME_MOVE_COUNT = game.move_count;
    GAME_META = meta;
    GAME_SEED_LO = seed_lo;
    GAME_SEED_HI = seed_hi;
    GAME_COMMIT = 1;

    SEVEN_SEG_DATA = playing ? game.move_count : game.seed;
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
    water_sort_start(&game, next, game.seed);
}

static void append_seed_digit(uint32_t digit)
{
    if (!seed_editing) {
        game.seed = 0;
        seed_editing = true;
    }
    if (game.seed > 429496729u ||
        (game.seed == 429496729u && digit > 5u)) {
        input_error = true;
        return;
    }
    game.seed = (game.seed << 3) + (game.seed << 1) + digit;
}

static uint32_t divide_by_ten(uint32_t value)
{
    uint32_t quotient = 0;
    uint32_t remainder = 0;
    int bit;
    for (bit = 31; bit >= 0; --bit) {
        remainder = (remainder << 1) | ((value >> bit) & 1u);
        if (remainder >= 10u) {
            remainder -= 10u;
            quotient |= 1u << bit;
        }
    }
    return quotient;
}

static void handle_menu_event(uint32_t event)
{
    input_error = false;
    if (event == KEY_EVENT_LEFT)
        cycle_difficulty(-1);
    else if (event == KEY_EVENT_RIGHT)
        cycle_difficulty(1);
    else if (event == KEY_EVENT_RESTART) {
        water_sort_start(&game, game.difficulty, seed_random());
        seed_editing = false;
    } else if (event == KEY_EVENT_BACKSPACE) {
        game.seed = seed_editing ? divide_by_ten(game.seed) : 0;
        seed_editing = true;
    } else if (event >= KEY_EVENT_DIGIT0 &&
               event < KEY_EVENT_DIGIT0 + 10u) {
        append_seed_digit(event - KEY_EVENT_DIGIT0);
    } else if (event == KEY_EVENT_CONFIRM) {
        water_sort_start(&game, game.difficulty, game.seed);
        playing = true;
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
        seed_editing = false;
        water_sort_cancel(&game);
    }
}

int main(void)
{
    water_sort_start(&game, WATER_SORT_NORMAL, seed_random());
    playing = false;
    seed_editing = false;
    input_error = false;
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
