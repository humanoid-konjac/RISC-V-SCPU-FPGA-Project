# Legacy assembly reference. The active firmware source is voice_game.c.
#
# Video MMIO base:      0xC0000000
# Microphone MMIO base: 0xD0000000
#
# Register allocation:
# x1  video base       x2  microphone base
# x3  previous frame   x4  player y
# x5  vertical speed   x6  obstacle x
# x7  gap center y     x8  score
# x9  control/state    x10-x18 temporaries

start:
    lui  x1, 0xc0000
    lui  x2, 0xd0000

    addi x4, x0, 224
    addi x5, x0, 0
    addi x6, x0, 620
    addi x7, x0, 240
    addi x8, x0, 0
    addi x9, x0, 3          # enabled + waiting/game-over overlay

    addi x10, x0, 1
    sw   x10, 0(x2)         # microphone enabled, automatic threshold
    sw   x9, 0(x1)
    sw   x4, 4(x1)
    sw   x6, 8(x1)
    sw   x7, 12(x1)
    sw   x8, 16(x1)
    lw   x3, 20(x1)

frame_wait:
    lw   x10, 20(x1)
    beq  x10, x3, frame_wait
    addi x3, x10, 0

    lw   x11, 4(x2)         # MIC_STATUS
    andi x12, x11, 2        # sticky sound/button event
    beq  x12, x0, no_input

    addi x13, x0, 2
    sw   x13, 4(x2)         # W1C MIC_STATUS.event_pending
    andi x14, x9, 2
    beq  x14, x0, flap

restart_game:
    addi x4, x0, 224
    addi x5, x0, 0
    addi x6, x0, 620
    addi x7, x0, 240
    addi x8, x0, 0
    addi x9, x0, 1
    j    write_state

flap:
    addi x5, x0, -7

no_input:
    andi x14, x9, 2
    bne  x14, x0, write_state

    addi x5, x5, 1         # gravity
    addi x15, x0, 8
    blt  x5, x15, speed_ok
    addi x5, x0, 8

speed_ok:
    add  x4, x4, x5
    blt  x4, x0, game_over
    addi x15, x0, 422      # ground 440 minus player height 18
    bge  x4, x15, game_over

    addi x6, x6, -3
    blt  x6, x0, reset_obstacle
    j    collision_test

reset_obstacle:
    addi x6, x0, 640
    addi x8, x8, 1
    andi x16, x8, 3
    slli x17, x16, 5       # *32
    slli x18, x16, 3       # *8
    add  x17, x17, x18     # *40
    addi x7, x17, 160      # gap centers: 160, 200, 240, 280

collision_test:
    addi x15, x0, 168      # player right edge
    bge  x6, x15, write_state
    addi x16, x0, 88       # player left minus pipe width
    bge  x16, x6, write_state

    addi x17, x7, -64      # gap top
    blt  x4, x17, game_over
    addi x17, x7, 47       # first y where player bottom exceeds gap
    bge  x4, x17, game_over
    j    write_state

game_over:
    addi x9, x0, 3
    addi x5, x0, 0

write_state:
    sw   x9, 0(x1)
    sw   x4, 4(x1)
    sw   x6, 8(x1)
    sw   x7, 12(x1)
    sw   x8, 16(x1)
    j    frame_wait
