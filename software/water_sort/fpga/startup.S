    .section .text.start
    .globl _start
    .type _start, @function

_start:
    la sp, __stack_top
    la t0, __bss_start
    la t1, __bss_end

.Lbss_loop:
    bgeu t0, t1, .Lbss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j .Lbss_loop

.Lbss_done:
    call main

.Lhalt:
    j .Lhalt

    .size _start, .-_start
