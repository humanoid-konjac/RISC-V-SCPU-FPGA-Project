#include <stdint.h>

#define VIDEO_BASE 0xc0000000u
#define MIC_BASE   0xd0000000u

#define MMIO32(address) (*(volatile uint32_t *)(address))

enum {
    GAME_CONTROL = 0x00,
    PLAYER_Y = 0x04,
    OBSTACLE_X = 0x08,
    GAP_Y = 0x0c,
    SCORE = 0x10,
    FRAME_SEQUENCE = 0x14,
    GAME_STATUS = 0x18,
};

enum {
    MIC_CONTROL = 0x00,
    MIC_STATUS = 0x04,
};

enum {
    GAME_ENABLED = 1u << 0,
    GAME_WAITING = 1u << 1,
    MIC_ENABLED = 1u << 0,
    MIC_EVENT_PENDING = 1u << 1,
};

enum {
    PLAYER_START_Y = 224,
    OBSTACLE_START_X = 620,
    OBSTACLE_RESET_X = 640,
    GAP_START_Y = 240,
    FLAP_VELOCITY = -10,
    MAX_FALL_VELOCITY = 8,
    GROUND_PLAYER_Y = 420,
    PLAYER_HITBOX_TOP = 4,
    PLAYER_HITBOX_BOTTOM = 20,
    PLAYER_HITBOX_RIGHT_X = 172,
    PLAYER_HITBOX_LEFT_MINUS_PIPE = 92,
    GAP_HALF_HEIGHT = 80,
    HIT_INVULNERABLE_FRAMES = 60,
    STARTING_LIVES = 3,
};

static inline uint32_t video_read(uint32_t offset)
{
    return MMIO32(VIDEO_BASE + offset);
}

static inline void video_write(uint32_t offset, uint32_t value)
{
    MMIO32(VIDEO_BASE + offset) = value;
}

static inline uint32_t mic_read(uint32_t offset)
{
    return MMIO32(MIC_BASE + offset);
}

static inline void mic_write(uint32_t offset, uint32_t value)
{
    MMIO32(MIC_BASE + offset) = value;
}

static inline void publish_state(uint32_t control, int32_t player_y,
                                 int32_t obstacle_x, int32_t gap_y,
                                 uint32_t score, uint32_t lives,
                                 uint32_t invulnerable_frames)
{
    video_write(GAME_CONTROL, control);
    video_write(PLAYER_Y, (uint32_t)player_y);
    video_write(OBSTACLE_X, (uint32_t)obstacle_x);
    video_write(GAP_Y, (uint32_t)gap_y);
    video_write(SCORE, score);
    video_write(GAME_STATUS,
                lives | ((invulnerable_frames != 0u) ? (1u << 8) : 0u));
}

__attribute__((noreturn)) void game_main(void)
{
    uint32_t previous_frame;
    uint32_t control = GAME_ENABLED | GAME_WAITING;
    uint32_t score = 0;
    uint32_t lives = STARTING_LIVES;
    uint32_t invulnerable_frames = 0;
    int32_t player_y = PLAYER_START_Y;
    int32_t velocity = 0;
    int32_t obstacle_x = OBSTACLE_START_X;
    int32_t gap_y = GAP_START_Y;

    mic_write(MIC_CONTROL, MIC_ENABLED);
    publish_state(control, player_y, obstacle_x, gap_y, score, lives,
                  invulnerable_frames);
    previous_frame = video_read(FRAME_SEQUENCE);

    for (;;) {
        uint32_t current_frame;
        uint32_t mic_status;

        do {
            current_frame = video_read(FRAME_SEQUENCE);
        } while (current_frame == previous_frame);
        previous_frame = current_frame;

        mic_status = mic_read(MIC_STATUS);
        if ((mic_status & MIC_EVENT_PENDING) != 0u) {
            mic_write(MIC_STATUS, MIC_EVENT_PENDING);

            if ((control & GAME_WAITING) != 0u) {
                player_y = PLAYER_START_Y;
                velocity = 0;
                obstacle_x = OBSTACLE_START_X;
                gap_y = GAP_START_Y;
                score = 0;
                lives = STARTING_LIVES;
                invulnerable_frames = 0;
                control = GAME_ENABLED;
                publish_state(control, player_y, obstacle_x, gap_y, score,
                              lives, invulnerable_frames);
                continue;
            }

            velocity = FLAP_VELOCITY;
        }

        if ((control & GAME_WAITING) != 0u) {
            publish_state(control, player_y, obstacle_x, gap_y, score, lives,
                          invulnerable_frames);
            continue;
        }

        if (invulnerable_frames != 0u)
            invulnerable_frames -= 1u;

        velocity += 1;
        if (velocity > MAX_FALL_VELOCITY)
            velocity = MAX_FALL_VELOCITY;
        player_y += velocity;

        obstacle_x -= 2;
        if (obstacle_x < 0) {
            uint32_t pattern;

            obstacle_x = OBSTACLE_RESET_X;
            score += 1u;
            pattern = score & 3u;
            gap_y = 160 + (int32_t)(pattern << 5) +
                    (int32_t)(pattern << 3);
        }

        if ((invulnerable_frames != 0u) &&
            ((player_y < 0) || (player_y >= GROUND_PLAYER_Y))) {
            player_y = PLAYER_START_Y;
            velocity = 0;
            obstacle_x = OBSTACLE_START_X;
            gap_y = GAP_START_Y;
        }

        if ((invulnerable_frames == 0u) &&
            (((player_y < 0) || (player_y >= GROUND_PLAYER_Y)) ||
             (((obstacle_x < PLAYER_HITBOX_RIGHT_X) &&
               (obstacle_x > PLAYER_HITBOX_LEFT_MINUS_PIPE)) &&
              (((player_y + PLAYER_HITBOX_TOP) <
                (gap_y - GAP_HALF_HEIGHT)) ||
               ((player_y + PLAYER_HITBOX_BOTTOM) >
                (gap_y + GAP_HALF_HEIGHT)))))) {
            if (lives > 1u) {
                lives -= 1u;
                invulnerable_frames = HIT_INVULNERABLE_FRAMES;
                player_y = PLAYER_START_Y;
                velocity = 0;
                obstacle_x = OBSTACLE_START_X;
                gap_y = GAP_START_Y;
            } else {
                lives = 0;
                control = GAME_ENABLED | GAME_WAITING;
                velocity = 0;
            }
        }

        publish_state(control, player_y, obstacle_x, gap_y, score, lives,
                      invulnerable_frames);
    }
}
