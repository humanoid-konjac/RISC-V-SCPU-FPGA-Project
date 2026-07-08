# Test file for 37 RV32I instructions:
# add/sub/and/or, lw/sw, beq, jalr/jal,
# ori/xor/xori/andi/addi,
# sll/sra/srl/slt/sltu/srai/slti/sltiu/slli/srli/lui/auipc,
# lb/lh/lbu/lhu/sb/sh, bne/blt/bge/bltu/bgeu.

        lui   x1, 0x12345
        auipc x2, 0
        addi  x3, x0, 10
        addi  x4, x0, 3
        add   x5, x3, x4
        sub   x6, x3, x4
        or    x7, x3, x4
        and   x8, x3, x4
        ori   x9, x4, 8
        xor   x10, x3, x4
        xori  x11, x3, 3
        andi  x12, x3, 6
        sll   x13, x4, x4
        addi  x31, x0, -16
        sra   x14, x31, x4
        addi  x31, x0, 16
        srl   x15, x31, x4
        slt   x16, x4, x3
        addi  x31, x0, -1
        sltu  x17, x3, x31
        srai  x18, x31, 4
        slti  x19, x4, 10
        sltiu x20, x4, 10
        slli  x21, x4, 2
        addi  x31, x0, 16
        srli  x22, x31, 2

        lui   x31, 0x12345
        addi  x31, x31, 0x678
        sw    x31, 0(x0)
        lw    x27, 0(x0)
        addi  x31, x0, -128
        sb    x31, 8(x0)
        lb    x23, 8(x0)
        lbu   x25, 8(x0)
        lui   x31, 0x8
        addi  x31, x31, 1
        sh    x31, 10(x0)
        lh    x24, 10(x0)
        lhu   x26, 10(x0)

        beq   x3, x3, beq_ok
        addi  x30, x0, 1
beq_ok:
        bne   x3, x4, bne_ok
        addi  x30, x0, 2
bne_ok:
        blt   x4, x3, blt_ok
        addi  x30, x0, 3
blt_ok:
        bge   x3, x4, bge_ok
        addi  x30, x0, 4
bge_ok:
        bltu  x4, x31, bltu_ok
        addi  x30, x0, 5
bltu_ok:
        bgeu  x31, x4, bgeu_ok
        addi  x30, x0, 6
bgeu_ok:
        jal   x28, jal_ok
        addi  x30, x0, 7
jal_ok:
        addi  x31, x0, jalr_ok
        jalr  x29, 0(x31)
        addi  x30, x0, 8
jalr_ok:
        jal   x0, done
done:
        jal   x0, done
