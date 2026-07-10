#include <stdint.h>

#include "mmio.h"

static void publish_color(uint32_t color)
{
    GAME_TUBE0 = color;
    GAME_UI = 0;
    GAME_MOVE_COUNT = 0;
    GAME_COMMIT = 1;
}

int main(void)
{
    uint32_t color = 1;

    publish_color(color);
    SEVEN_SEG_DATA = color;
    LED_DATA = color;

    for (;;) {
        uint32_t event;

        if ((KEY_STATUS & 1u) == 0u) {
            continue;
        }

        event = KEY_CODE;
        SEVEN_SEG_DATA = event;
        LED_DATA = event;

        if (event == KEY_EVENT_LEFT) {
            color = color == 1u ? 6u : color - 1u;
            publish_color(color);
        } else if (event == KEY_EVENT_RIGHT) {
            color = color == 6u ? 1u : color + 1u;
            publish_color(color);
        } else if (event == KEY_EVENT_RESTART) {
            color = 1u;
            publish_color(color);
        }

        KEY_ACK = 1;
    }
}
