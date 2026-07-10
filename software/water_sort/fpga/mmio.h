#ifndef WATER_SORT_FPGA_MMIO_H
#define WATER_SORT_FPGA_MMIO_H

#include <stdint.h>

#define MMIO32(address) (*(volatile uint32_t *)(uintptr_t)(address))

#define KEY_STATUS      MMIO32(0xd0000000u)
#define KEY_CODE        MMIO32(0xd0000004u)
#define KEY_ACK         MMIO32(0xd0000008u)

#define GAME_TUBE(index) MMIO32(0xd0000020u + ((uint32_t)(index) << 2))
#define GAME_TUBE0       GAME_TUBE(0)
#define GAME_UI         MMIO32(0xd0000040u)
#define GAME_MOVE_COUNT MMIO32(0xd0000044u)
#define GAME_COMMIT     MMIO32(0xd0000048u)

#define SEVEN_SEG_DATA  MMIO32(0xe0000000u)
#define LED_DATA        MMIO32(0xf0000000u)

#define GAME_UI_CURSOR_MASK       0x00000007u
#define GAME_UI_SELECTED_SHIFT    4u
#define GAME_UI_SELECTED_VALID    0x00000080u
#define GAME_UI_FINISHED          0x00000100u

enum {
    KEY_EVENT_LEFT = 1,
    KEY_EVENT_RIGHT = 2,
    KEY_EVENT_CONFIRM = 3,
    KEY_EVENT_CANCEL = 4,
    KEY_EVENT_RESTART = 5
};

#endif
