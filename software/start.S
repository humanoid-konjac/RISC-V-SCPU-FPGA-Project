    .option norvc
    .option norelax
    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function

_start:
    addi sp, zero, 1024
    jal  ra, game_main

.Lhang:
    jal  zero, .Lhang

    .size _start, . - _start
