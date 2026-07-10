    .section .text.isa_coverage
    .globl isa_coverage
    .type isa_coverage, @function

isa_coverage:
    addi sp, sp, -16
    addi t0, zero, 5
    addi t1, zero, 2

    sw t0, 0(sp)
    sh t1, 4(sp)
    sb t0, 6(sp)
    lw t2, 0(sp)
    lh t2, 4(sp)
    lhu t2, 4(sp)
    lb t2, 6(sp)
    lbu t2, 6(sp)

    add t2, t0, t1
    sub t2, t0, t1
    sll t2, t0, t1
    slt t2, t1, t0
    sltu t2, t1, t0
    xor t2, t0, t1
    srl t2, t0, t1
    sra t2, t0, t1
    or t2, t0, t1
    and t2, t0, t1

    addi t2, t0, -1
    slli t2, t1, 1
    slti t2, t1, 3
    sltiu t2, t1, 3
    xori t2, t0, 3
    srli t2, t0, 1
    srai t2, t0, 1
    ori t2, t0, 8
    andi t2, t0, 3
    lui t2, 0x12345
    auipc t2, 0

    beq zero, zero, .Lbeq_ok
    addi zero, zero, 0
.Lbeq_ok:
    bne t0, t1, .Lbne_ok
    addi zero, zero, 0
.Lbne_ok:
    blt t1, t0, .Lblt_ok
    addi zero, zero, 0
.Lblt_ok:
    bge t0, t1, .Lbge_ok
    addi zero, zero, 0
.Lbge_ok:
    bltu t1, t0, .Lbltu_ok
    addi zero, zero, 0
.Lbltu_ok:
    bgeu t0, t1, .Lbgeu_ok
    addi zero, zero, 0
.Lbgeu_ok:
    jal t6, .Ljal_ok
.Ljal_ok:
    auipc t5, 0
    addi t5, t5, 12
    jalr t6, 0(t5)
.Ljalr_ok:
    addi sp, sp, 16
    jalr zero, 0(ra)

    .size isa_coverage, .-isa_coverage
