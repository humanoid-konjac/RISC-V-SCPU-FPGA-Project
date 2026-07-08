`timescale 1ns/1ps

`include "ctrl_encode_def.v"

module ctrl(Op, Funct7, Funct3, Zero,
            RegWrite, MemWrite,
            EXTOp, ALUOp, NPCOp,
            ALUSrc, GPRSel, WDSel, DMType
            );

   input  [6:0] Op;
   input  [6:0] Funct7;
   input  [2:0] Funct3;
   input        Zero;

   output       RegWrite;
   output       MemWrite;
   output [5:0] EXTOp;
   output [4:0] ALUOp;
   output [2:0] NPCOp;
   output       ALUSrc;
   output [1:0] GPRSel;
   output [1:0] WDSel;
   output [2:0] DMType;

   wire rtype   = (Op == 7'b0110011);
   wire itype_r = (Op == 7'b0010011);
   wire itype_l = (Op == 7'b0000011);
   wire stype   = (Op == 7'b0100011);
   wire sbtype  = (Op == 7'b1100011);
   wire i_jalr  = (Op == 7'b1100111);
   wire i_jal   = (Op == 7'b1101111);
   wire i_lui   = (Op == 7'b0110111);
   wire i_auipc = (Op == 7'b0010111);

   wire i_add  = rtype   & (Funct3 == 3'b000) & (Funct7 == 7'b0000000);
   wire i_sub  = rtype   & (Funct3 == 3'b000) & (Funct7 == 7'b0100000);
   wire i_sll  = rtype   & (Funct3 == 3'b001) & (Funct7 == 7'b0000000);
   wire i_slt  = rtype   & (Funct3 == 3'b010) & (Funct7 == 7'b0000000);
   wire i_sltu = rtype   & (Funct3 == 3'b011) & (Funct7 == 7'b0000000);
   wire i_xor  = rtype   & (Funct3 == 3'b100) & (Funct7 == 7'b0000000);
   wire i_srl  = rtype   & (Funct3 == 3'b101) & (Funct7 == 7'b0000000);
   wire i_sra  = rtype   & (Funct3 == 3'b101) & (Funct7 == 7'b0100000);
   wire i_or   = rtype   & (Funct3 == 3'b110) & (Funct7 == 7'b0000000);
   wire i_and  = rtype   & (Funct3 == 3'b111) & (Funct7 == 7'b0000000);

   wire i_addi  = itype_r & (Funct3 == 3'b000);
   wire i_slli  = itype_r & (Funct3 == 3'b001) & (Funct7 == 7'b0000000);
   wire i_slti  = itype_r & (Funct3 == 3'b010);
   wire i_sltiu = itype_r & (Funct3 == 3'b011);
   wire i_xori  = itype_r & (Funct3 == 3'b100);
   wire i_srli  = itype_r & (Funct3 == 3'b101) & (Funct7 == 7'b0000000);
   wire i_srai  = itype_r & (Funct3 == 3'b101) & (Funct7 == 7'b0100000);
   wire i_ori   = itype_r & (Funct3 == 3'b110);
   wire i_andi  = itype_r & (Funct3 == 3'b111);

   wire i_beq  = sbtype & (Funct3 == 3'b000);
   wire i_bne  = sbtype & (Funct3 == 3'b001);
   wire i_blt  = sbtype & (Funct3 == 3'b100);
   wire i_bge  = sbtype & (Funct3 == 3'b101);
   wire i_bltu = sbtype & (Funct3 == 3'b110);
   wire i_bgeu = sbtype & (Funct3 == 3'b111);

   assign RegWrite = rtype | itype_r | itype_l | i_jalr | i_jal | i_lui | i_auipc;
   assign MemWrite = stype;
   assign ALUSrc   = itype_r | itype_l | stype | i_jalr | i_lui | i_auipc;

   assign EXTOp = (i_slli | i_srli | i_srai) ? `EXT_CTRL_ITYPE_SHAMT :
                  (itype_r | itype_l | i_jalr) ? `EXT_CTRL_ITYPE :
                  stype ? `EXT_CTRL_STYPE :
                  sbtype ? `EXT_CTRL_BTYPE :
                  (i_lui | i_auipc) ? `EXT_CTRL_UTYPE :
                  i_jal ? `EXT_CTRL_JTYPE :
                  6'b000000;

   assign WDSel = itype_l ? `WDSel_FromMEM :
                  (i_jal | i_jalr) ? `WDSel_FromPC :
                  `WDSel_FromALU;

   assign NPCOp = i_jalr ? `NPC_JALR :
                  i_jal ? `NPC_JUMP :
                  (sbtype & Zero) ? `NPC_BRANCH :
                  `NPC_PLUS4;

   assign ALUOp = (i_lui) ? `ALUOp_lui :
                  (i_auipc) ? `ALUOp_auipc :
                  (i_sub | i_beq) ? `ALUOp_sub :
                  (i_bne) ? `ALUOp_bne :
                  (i_blt) ? `ALUOp_blt :
                  (i_bge) ? `ALUOp_bge :
                  (i_bltu) ? `ALUOp_bltu :
                  (i_bgeu) ? `ALUOp_bgeu :
                  (i_slt | i_slti) ? `ALUOp_slt :
                  (i_sltu | i_sltiu) ? `ALUOp_sltu :
                  (i_xor | i_xori) ? `ALUOp_xor :
                  (i_or | i_ori) ? `ALUOp_or :
                  (i_and | i_andi) ? `ALUOp_and :
                  (i_sll | i_slli) ? `ALUOp_sll :
                  (i_srl | i_srli) ? `ALUOp_srl :
                  (i_sra | i_srai) ? `ALUOp_sra :
                  (i_add | i_addi | itype_l | stype | i_jalr) ? `ALUOp_add :
                  `ALUOp_nop;

   assign DMType = (Funct3 == 3'b000) ? `dm_byte :
                   (Funct3 == 3'b001) ? `dm_halfword :
                   (Funct3 == 3'b100) ? `dm_byte_unsigned :
                   (Funct3 == 3'b101) ? `dm_halfword_unsigned :
                   `dm_word;

   assign GPRSel = `GPRSel_RD;

endmodule
