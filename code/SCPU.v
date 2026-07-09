`timescale 1ns/1ps
`default_nettype none

`include "ctrl_encode_def.v"

module SCPU(
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire        MIO_ready,  // Not used
    input  wire [31:0] inst_in,
    input  wire [31:0] Data_in,

    output wire        mem_w,
    output wire [31:0] PC_out,
    output wire [31:0] Addr_out,
    output wire [2:0]  dm_ctrl,
    output wire [31:0] Data_out,
    output wire        CPU_MIO,    // Not used
    input  wire        INT
);
    localparam [6:0] OP_RTYPE  = 7'b0110011;
    localparam [6:0] OP_ITYPE  = 7'b0010011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_MISC   = 7'b0001111;
    localparam [6:0] OP_SYSTEM = 7'b1110011;

    localparam [11:0] CSR_MSTATUS = 12'h300;
    localparam [11:0] CSR_MIE     = 12'h304;
    localparam [11:0] CSR_MTVEC   = 12'h305;
    localparam [11:0] CSR_MEPC    = 12'h341;
    localparam [11:0] CSR_MCAUSE  = 12'h342;

    localparam [31:0] TRAP_VECTOR_RESET = 32'h0000_0100;
    localparam [31:0] MCAUSE_ILLEGAL    = 32'd2;
    localparam [31:0] MCAUSE_ECALL_M    = 32'd11;
    localparam [31:0] MCAUSE_TIMER_M    = 32'h8000_0007;

    localparam MSTATUS_MIE_BIT  = 3;
    localparam MSTATUS_MPIE_BIT = 7;
    localparam MIE_MTIE_BIT     = 7;

    assign CPU_MIO = 1'b0;

    wire _unused_inputs = &{1'b0, MIO_ready};

    function [31:0] branch_imm;
        input [31:0] inst;
        begin
            branch_imm = {{19{inst[31]}}, inst[31], inst[7],
                          inst[30:25], inst[11:8], 1'b0};
        end
    endfunction

    function [31:0] jump_imm;
        input [31:0] inst;
        begin
            jump_imm = {{11{inst[31]}}, inst[31], inst[19:12],
                        inst[20], inst[30:21], 1'b0};
        end
    endfunction

    reg [31:0] pc_reg;
    assign PC_out = pc_reg;

    wire [31:0] if_pc4 = pc_reg + 32'd4;
    wire [6:0]  if_op = inst_in[6:0];
    wire        if_is_branch = (if_op == OP_BRANCH);
    wire        if_is_jal = (if_op == OP_JAL);
    wire        if_pred_taken = if_is_jal || (if_is_branch && inst_in[31]);
    wire [31:0] if_pred_offset = if_is_jal ? jump_imm(inst_in) : branch_imm(inst_in);
    wire [31:0] if_pred_target = if_pred_taken ? (pc_reg + if_pred_offset) : if_pc4;

    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_pc4;
    reg [31:0] if_id_inst;
    reg        if_id_pred_taken;
    reg [31:0] if_id_pred_target;

    wire [6:0] id_op     = if_id_inst[6:0];
    wire [6:0] id_funct7 = if_id_inst[31:25];
    wire [2:0] id_funct3 = if_id_inst[14:12];
    wire [4:0] id_rs1    = if_id_inst[19:15];
    wire [4:0] id_rs2    = if_id_inst[24:20];
    wire [4:0] id_rd     = if_id_inst[11:7];

    wire [4:0]  id_iimm_shamt = if_id_inst[24:20];
    wire [11:0] id_iimm       = if_id_inst[31:20];
    wire [11:0] id_simm       = {if_id_inst[31:25], if_id_inst[11:7]};
    wire [11:0] id_bimm       = {if_id_inst[31], if_id_inst[7],
                                 if_id_inst[30:25], if_id_inst[11:8]};
    wire [19:0] id_uimm       = if_id_inst[31:12];
    wire [19:0] id_jimm       = {if_id_inst[31], if_id_inst[19:12],
                                 if_id_inst[20], if_id_inst[30:21]};

    wire        id_regwrite;
    wire        id_memwrite;
    wire [5:0]  id_extop;
    wire [4:0]  id_aluop;
    wire [2:0]  id_npcop_unused;
    wire        id_alusrc;
    wire [1:0]  id_gprsel_unused;
    wire [1:0]  id_wdsel;
    wire [2:0]  id_dm_ctrl;
    wire [31:0] id_immout;

    wire        id_is_rtype  = (id_op == OP_RTYPE);
    wire        id_is_itype  = (id_op == OP_ITYPE);
    wire        id_is_branch = (id_op == OP_BRANCH);
    wire        id_is_jal    = (id_op == OP_JAL);
    wire        id_is_jalr   = (id_op == OP_JALR);
    wire        id_is_load   = (id_op == OP_LOAD);
    wire        id_is_store  = (id_op == OP_STORE);
    wire        id_is_lui    = (id_op == OP_LUI);
    wire        id_is_auipc  = (id_op == OP_AUIPC);
    wire        id_is_system = (id_op == OP_SYSTEM);

    wire [11:0] id_csr_addr = id_iimm;
    wire [31:0] id_csr_zimm = {27'b0, id_rs1};
    wire        id_csr_addr_ok = (id_csr_addr == CSR_MSTATUS) ||
                                 (id_csr_addr == CSR_MIE) ||
                                 (id_csr_addr == CSR_MTVEC) ||
                                 (id_csr_addr == CSR_MEPC) ||
                                 (id_csr_addr == CSR_MCAUSE);
    wire        id_csr_funct_ok = (id_funct3 == 3'b001) ||
                                  (id_funct3 == 3'b010) ||
                                  (id_funct3 == 3'b011) ||
                                  (id_funct3 == 3'b101) ||
                                  (id_funct3 == 3'b110) ||
                                  (id_funct3 == 3'b111);
    wire        id_is_csr = id_is_system && id_csr_funct_ok && id_csr_addr_ok;
    wire        id_csr_uses_uimm = id_funct3[2];
    wire        id_csr_uses_rs1 = id_is_csr && !id_csr_uses_uimm && (id_rs1 != 5'd0);
    wire        id_is_ecall = id_is_system && (if_id_inst == 32'h0000_0073);
    wire        id_is_mret = id_is_system && (if_id_inst == 32'h3020_0073);
    wire        id_is_fence = (id_op == OP_MISC) &&
                              ((id_funct3 == 3'b000) || (id_funct3 == 3'b001));

    wire        id_rtype_ok =
        ((id_funct3 == 3'b000) && ((id_funct7 == 7'b0000000) ||
                                   (id_funct7 == 7'b0100000))) ||
        ((id_funct3 == 3'b001) && (id_funct7 == 7'b0000000)) ||
        ((id_funct3 == 3'b010) && (id_funct7 == 7'b0000000)) ||
        ((id_funct3 == 3'b011) && (id_funct7 == 7'b0000000)) ||
        ((id_funct3 == 3'b100) && (id_funct7 == 7'b0000000)) ||
        ((id_funct3 == 3'b101) && ((id_funct7 == 7'b0000000) ||
                                   (id_funct7 == 7'b0100000))) ||
        ((id_funct3 == 3'b110) && (id_funct7 == 7'b0000000)) ||
        ((id_funct3 == 3'b111) && (id_funct7 == 7'b0000000));
    wire        id_itype_ok =
        (id_funct3 == 3'b000) ||
        ((id_funct3 == 3'b001) && (id_funct7 == 7'b0000000)) ||
        (id_funct3 == 3'b010) ||
        (id_funct3 == 3'b011) ||
        (id_funct3 == 3'b100) ||
        ((id_funct3 == 3'b101) && ((id_funct7 == 7'b0000000) ||
                                   (id_funct7 == 7'b0100000))) ||
        (id_funct3 == 3'b110) ||
        (id_funct3 == 3'b111);
    wire        id_load_ok = (id_funct3 == 3'b000) ||
                             (id_funct3 == 3'b001) ||
                             (id_funct3 == 3'b010) ||
                             (id_funct3 == 3'b100) ||
                             (id_funct3 == 3'b101);
    wire        id_store_ok = (id_funct3 == 3'b000) ||
                              (id_funct3 == 3'b001) ||
                              (id_funct3 == 3'b010);
    wire        id_branch_ok = (id_funct3 == 3'b000) ||
                               (id_funct3 == 3'b001) ||
                               (id_funct3 == 3'b100) ||
                               (id_funct3 == 3'b101) ||
                               (id_funct3 == 3'b110) ||
                               (id_funct3 == 3'b111);
    wire        id_jalr_ok = (id_funct3 == 3'b000);
    wire        id_system_ok = id_is_ecall || id_is_mret || id_is_csr;
    wire        id_inst_ok =
        (id_is_rtype && id_rtype_ok) ||
        (id_is_itype && id_itype_ok) ||
        (id_is_load && id_load_ok) ||
        (id_is_store && id_store_ok) ||
        (id_is_branch && id_branch_ok) ||
        (id_is_jalr && id_jalr_ok) ||
        id_is_jal || id_is_lui || id_is_auipc || id_is_fence || id_system_ok;
    wire        id_illegal = !id_inst_ok;
    wire        id_regwrite_eff = id_regwrite || id_is_csr;
    wire [1:0]  id_wdsel_eff = id_is_csr ? `WDSel_FromALU : id_wdsel;

    wire        id_uses_rs1 = (id_op == OP_RTYPE) || (id_op == OP_ITYPE) ||
                              id_is_load || id_is_store || id_is_branch ||
                              id_is_jalr || id_csr_uses_rs1;
    wire        id_uses_rs2 = (id_op == OP_RTYPE) || id_is_store ||
                              id_is_branch;
    wire        _unused_id_decode = &{1'b0, id_npcop_unused, id_gprsel_unused};

    ctrl U_ctrl(
        .Op(id_op),
        .Funct7(id_funct7),
        .Funct3(id_funct3),
        .Zero(1'b0),
        .RegWrite(id_regwrite),
        .MemWrite(id_memwrite),
        .EXTOp(id_extop),
        .ALUOp(id_aluop),
        .NPCOp(id_npcop_unused),
        .ALUSrc(id_alusrc),
        .GPRSel(id_gprsel_unused),
        .WDSel(id_wdsel),
        .DMType(id_dm_ctrl)
    );

    EXT U_EXT(
        .iimm_shamt(id_iimm_shamt),
        .iimm(id_iimm),
        .simm(id_simm),
        .bimm(id_bimm),
        .uimm(id_uimm),
        .jimm(id_jimm),
        .EXTOp(id_extop),
        .immout(id_immout)
    );

    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc4;
    reg        id_ex_pred_taken;
    reg [31:0] id_ex_pred_target;
    reg [31:0] id_ex_rd1;
    reg [31:0] id_ex_rd2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg        id_ex_regwrite;
    reg        id_ex_memwrite;
    reg [4:0]  id_ex_aluop;
    reg        id_ex_alusrc;
    reg [1:0]  id_ex_wdsel;
    reg [2:0]  id_ex_dm_ctrl;
    reg        id_ex_is_branch;
    reg        id_ex_is_jal;
    reg        id_ex_is_jalr;
    reg        id_ex_illegal;
    reg        id_ex_is_ecall;
    reg        id_ex_is_mret;
    reg        id_ex_is_csr;
    reg [2:0]  id_ex_csr_op;
    reg [11:0] id_ex_csr_addr;
    reg [31:0] id_ex_csr_zimm;
    reg        id_ex_csr_uses_uimm;

    reg        ex_mem_valid;
    reg [31:0] ex_mem_aluout;
    reg [31:0] ex_mem_store_data;
    reg [31:0] ex_mem_pc4;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_regwrite;
    reg        ex_mem_memwrite;
    reg [1:0]  ex_mem_wdsel;
    reg [2:0]  ex_mem_dm_ctrl;

    reg        mem_wb_valid;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_aluout;
    reg [31:0] mem_wb_pc4;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_regwrite;
    reg [1:0]  mem_wb_wdsel;

    reg [31:0] csr_mstatus;
    reg [31:0] csr_mie;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;

    reg int_sync0;
    reg int_sync1;
    reg int_sync1_d;
    reg timer_irq_pending;

    wire [31:0] rf_rd1_raw;
    wire [31:0] rf_rd2_raw;
    wire [31:0] rf_reg_data_unused;

    reg [31:0] wb_wd;
    wire       wb_regwrite = mem_wb_valid && mem_wb_regwrite;

    always @(*) begin
        case (mem_wb_wdsel)
            `WDSel_FromMEM: wb_wd = mem_wb_mem_data;
            `WDSel_FromPC:  wb_wd = mem_wb_pc4;
            default:        wb_wd = mem_wb_aluout;
        endcase
    end

    RF U_RF(
        .clk(clk),
        .rst(reset),
        .RFWr(wb_regwrite),
        .A1(id_rs1),
        .A2(id_rs2),
        .A3(mem_wb_rd),
        .WD(wb_wd),
        .reg_sel(5'b0),
        .RD1(rf_rd1_raw),
        .RD2(rf_rd2_raw),
        .reg_data(rf_reg_data_unused)
    );

    wire [31:0] id_rd1 = (wb_regwrite && (mem_wb_rd != 5'd0) &&
                          (mem_wb_rd == id_rs1)) ? wb_wd : rf_rd1_raw;
    wire [31:0] id_rd2 = (wb_regwrite && (mem_wb_rd != 5'd0) &&
                          (mem_wb_rd == id_rs2)) ? wb_wd : rf_rd2_raw;

    reg [31:0] ex_mem_forward_value;
    always @(*) begin
        case (ex_mem_wdsel)
            `WDSel_FromMEM: ex_mem_forward_value = Data_in;
            `WDSel_FromPC:  ex_mem_forward_value = ex_mem_pc4;
            default:        ex_mem_forward_value = ex_mem_aluout;
        endcase
    end

    wire ex_mem_can_forward = ex_mem_valid && ex_mem_regwrite && (ex_mem_rd != 5'd0);
    wire mem_wb_can_forward = wb_regwrite && (mem_wb_rd != 5'd0);

    reg [31:0] ex_src_a;
    reg [31:0] ex_src_b_raw;
    always @(*) begin
        ex_src_a = id_ex_rd1;
        if (ex_mem_can_forward && (ex_mem_rd == id_ex_rs1))
            ex_src_a = ex_mem_forward_value;
        else if (mem_wb_can_forward && (mem_wb_rd == id_ex_rs1))
            ex_src_a = wb_wd;

        ex_src_b_raw = id_ex_rd2;
        if (ex_mem_can_forward && (ex_mem_rd == id_ex_rs2))
            ex_src_b_raw = ex_mem_forward_value;
        else if (mem_wb_can_forward && (mem_wb_rd == id_ex_rs2))
            ex_src_b_raw = wb_wd;
    end

    wire [31:0] ex_alu_b = id_ex_alusrc ? id_ex_imm : ex_src_b_raw;
    wire [31:0] ex_aluout;
    wire        ex_zero;

	    alu U_alu(
	        .A(ex_src_a),
	        .B(ex_alu_b),
        .ALUOp(id_ex_aluop),
        .C(ex_aluout),
        .Zero(ex_zero),
	        .PC(id_ex_pc)
	    );

    reg [31:0] ex_csr_read_data;
    always @(*) begin
        case (id_ex_csr_addr)
            CSR_MSTATUS: ex_csr_read_data = csr_mstatus;
            CSR_MIE:     ex_csr_read_data = csr_mie;
            CSR_MTVEC:   ex_csr_read_data = csr_mtvec;
            CSR_MEPC:    ex_csr_read_data = csr_mepc;
            CSR_MCAUSE:  ex_csr_read_data = csr_mcause;
            default:     ex_csr_read_data = 32'b0;
        endcase
    end

    wire [31:0] ex_csr_src = id_ex_csr_uses_uimm ? id_ex_csr_zimm : ex_src_a;

    reg [31:0] ex_csr_write_data;
    reg        ex_csr_do_write;
    always @(*) begin
        ex_csr_write_data = ex_csr_read_data;
        ex_csr_do_write = 1'b0;

        case (id_ex_csr_op)
            3'b001, 3'b101: begin
                ex_csr_write_data = ex_csr_src;
                ex_csr_do_write = 1'b1;
            end

            3'b010, 3'b110: begin
                ex_csr_write_data = ex_csr_read_data | ex_csr_src;
                ex_csr_do_write = (ex_csr_src != 32'b0);
            end

            3'b011, 3'b111: begin
                ex_csr_write_data = ex_csr_read_data & ~ex_csr_src;
                ex_csr_do_write = (ex_csr_src != 32'b0);
            end

            default: begin
                ex_csr_write_data = ex_csr_read_data;
                ex_csr_do_write = 1'b0;
            end
        endcase
    end

	    wire        ex_branch_taken = id_ex_is_branch && ex_zero;
	    wire [31:0] ex_pc_target = id_ex_pc + id_ex_imm;
	    wire [31:0] ex_jalr_sum = ex_src_a + id_ex_imm;
    wire [31:0] ex_jalr_target = {ex_jalr_sum[31:1], 1'b0};
    wire        ex_actual_taken = id_ex_is_jal || id_ex_is_jalr || ex_branch_taken;
    wire [31:0] ex_actual_target =
        id_ex_is_jalr ? ex_jalr_target :
        ((id_ex_is_jal || ex_branch_taken) ? ex_pc_target : id_ex_pc4);
    wire        ex_is_control = id_ex_valid &&
                                (id_ex_is_branch || id_ex_is_jal || id_ex_is_jalr);
	    wire        ex_redirect = ex_is_control &&
	                              ((ex_actual_taken != id_ex_pred_taken) ||
	                               (ex_actual_target != id_ex_pred_target));
    wire        timer_irq_enabled = timer_irq_pending &&
                                    csr_mstatus[MSTATUS_MIE_BIT] &&
                                    csr_mie[MIE_MTIE_BIT];
    wire        ex_sync_trap = id_ex_valid &&
                               (id_ex_illegal || id_ex_is_ecall);
    wire        ex_timer_trap = id_ex_valid && !ex_sync_trap &&
                                timer_irq_enabled;
    wire        ex_take_trap = ex_sync_trap || ex_timer_trap;

    reg [31:0] ex_trap_cause;
    always @(*) begin
        if (id_ex_illegal)
            ex_trap_cause = MCAUSE_ILLEGAL;
        else if (id_ex_is_ecall)
            ex_trap_cause = MCAUSE_ECALL_M;
        else
            ex_trap_cause = MCAUSE_TIMER_M;
    end

    wire        ex_mret_redirect = id_ex_valid && id_ex_is_mret &&
                                   !ex_take_trap;
    wire        ex_pipeline_redirect = ex_take_trap || ex_mret_redirect ||
                                       ex_redirect;
    wire [31:0] ex_trap_target = {csr_mtvec[31:2], 2'b00};
    wire [31:0] ex_redirect_target =
        ex_take_trap ? ex_trap_target :
        (ex_mret_redirect ? csr_mepc : ex_actual_target);
    wire        ex_kill_current = ex_take_trap || ex_mret_redirect;
    wire [31:0] ex_exec_result = id_ex_is_csr ? ex_csr_read_data :
                                                ex_aluout;
    wire        ex_csr_write_enable = id_ex_valid && id_ex_is_csr &&
                                      ex_csr_do_write && !ex_take_trap;

	    wire        load_use_stall = if_id_valid && id_ex_valid &&
	                                 (id_ex_wdsel == `WDSel_FromMEM) &&
	                                 id_ex_regwrite && (id_ex_rd != 5'd0) &&
                                 ((id_uses_rs1 && (id_ex_rd == id_rs1)) ||
                                  (id_uses_rs2 && (id_ex_rd == id_rs2)));

    assign mem_w    = ex_mem_valid && ex_mem_memwrite;
    assign Addr_out = ex_mem_aluout;
    assign Data_out = ex_mem_store_data;
    assign dm_ctrl  = ex_mem_valid ? ex_mem_dm_ctrl : `dm_word;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_reg <= 32'h0000_0000;

            if_id_valid <= 1'b0;
            if_id_pc <= 32'b0;
            if_id_pc4 <= 32'b0;
            if_id_inst <= 32'b0;
            if_id_pred_taken <= 1'b0;
            if_id_pred_target <= 32'b0;

            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_pc4 <= 32'b0;
            id_ex_pred_taken <= 1'b0;
            id_ex_pred_target <= 32'b0;
            id_ex_rd1 <= 32'b0;
            id_ex_rd2 <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;
            id_ex_rd <= 5'b0;
            id_ex_regwrite <= 1'b0;
            id_ex_memwrite <= 1'b0;
            id_ex_aluop <= `ALUOp_nop;
            id_ex_alusrc <= 1'b0;
            id_ex_wdsel <= `WDSel_FromALU;
	            id_ex_dm_ctrl <= `dm_word;
	            id_ex_is_branch <= 1'b0;
	            id_ex_is_jal <= 1'b0;
	            id_ex_is_jalr <= 1'b0;
                id_ex_illegal <= 1'b0;
                id_ex_is_ecall <= 1'b0;
                id_ex_is_mret <= 1'b0;
                id_ex_is_csr <= 1'b0;
                id_ex_csr_op <= 3'b0;
                id_ex_csr_addr <= 12'b0;
                id_ex_csr_zimm <= 32'b0;
                id_ex_csr_uses_uimm <= 1'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_aluout <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_pc4 <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_regwrite <= 1'b0;
            ex_mem_memwrite <= 1'b0;
            ex_mem_wdsel <= `WDSel_FromALU;
            ex_mem_dm_ctrl <= `dm_word;

            mem_wb_valid <= 1'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_aluout <= 32'b0;
            mem_wb_pc4 <= 32'b0;
	            mem_wb_rd <= 5'b0;
	            mem_wb_regwrite <= 1'b0;
	            mem_wb_wdsel <= `WDSel_FromALU;
                csr_mstatus <= 32'b0;
                csr_mie <= 32'b0;
                csr_mtvec <= TRAP_VECTOR_RESET;
                csr_mepc <= 32'b0;
                csr_mcause <= 32'b0;
                int_sync0 <= 1'b0;
                int_sync1 <= 1'b0;
                int_sync1_d <= 1'b0;
                timer_irq_pending <= 1'b0;
	        end else begin
                int_sync0 <= INT;
                int_sync1 <= int_sync0;
                int_sync1_d <= int_sync1;

                if (int_sync1 && !int_sync1_d)
                    timer_irq_pending <= 1'b1;

                if (en && ex_timer_trap)
                    timer_irq_pending <= 1'b0;

                if (en) begin
	            if (ex_pipeline_redirect)
	                pc_reg <= ex_redirect_target;
	            else if (!load_use_stall)
	                pc_reg <= if_pred_target;

	            if (ex_pipeline_redirect) begin
	                if_id_valid <= 1'b0;
	                if_id_pc <= 32'b0;
                if_id_pc4 <= 32'b0;
                if_id_inst <= 32'b0;
                if_id_pred_taken <= 1'b0;
                if_id_pred_target <= 32'b0;
            end else if (!load_use_stall) begin
                if_id_valid <= 1'b1;
                if_id_pc <= pc_reg;
                if_id_pc4 <= if_pc4;
                if_id_inst <= inst_in;
                if_id_pred_taken <= if_pred_taken;
                if_id_pred_target <= if_pred_target;
            end

	            if (ex_pipeline_redirect || load_use_stall) begin
	                id_ex_valid <= 1'b0;
                id_ex_pc <= 32'b0;
                id_ex_pc4 <= 32'b0;
                id_ex_pred_taken <= 1'b0;
                id_ex_pred_target <= 32'b0;
                id_ex_rd1 <= 32'b0;
                id_ex_rd2 <= 32'b0;
                id_ex_imm <= 32'b0;
                id_ex_rs1 <= 5'b0;
                id_ex_rs2 <= 5'b0;
                id_ex_rd <= 5'b0;
                id_ex_regwrite <= 1'b0;
                id_ex_memwrite <= 1'b0;
                id_ex_aluop <= `ALUOp_nop;
                id_ex_alusrc <= 1'b0;
                id_ex_wdsel <= `WDSel_FromALU;
	                id_ex_dm_ctrl <= `dm_word;
	                id_ex_is_branch <= 1'b0;
	                id_ex_is_jal <= 1'b0;
	                id_ex_is_jalr <= 1'b0;
                    id_ex_illegal <= 1'b0;
                    id_ex_is_ecall <= 1'b0;
                    id_ex_is_mret <= 1'b0;
                    id_ex_is_csr <= 1'b0;
                    id_ex_csr_op <= 3'b0;
                    id_ex_csr_addr <= 12'b0;
                    id_ex_csr_zimm <= 32'b0;
                    id_ex_csr_uses_uimm <= 1'b0;
	            end else begin
	                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_pc4 <= if_id_pc4;
                id_ex_pred_taken <= if_id_pred_taken;
                id_ex_pred_target <= if_id_pred_target;
                id_ex_rd1 <= id_rd1;
                id_ex_rd2 <= id_rd2;
                id_ex_imm <= id_immout;
                id_ex_rs1 <= id_rs1;
                id_ex_rs2 <= id_rs2;
                id_ex_rd <= id_rd;
	                id_ex_regwrite <= id_regwrite_eff;
	                id_ex_memwrite <= id_memwrite;
	                id_ex_aluop <= id_aluop;
	                id_ex_alusrc <= id_alusrc;
	                id_ex_wdsel <= id_wdsel_eff;
	                id_ex_dm_ctrl <= id_dm_ctrl;
	                id_ex_is_branch <= id_is_branch;
	                id_ex_is_jal <= id_is_jal;
	                id_ex_is_jalr <= id_is_jalr;
                    id_ex_illegal <= id_illegal;
                    id_ex_is_ecall <= id_is_ecall;
                    id_ex_is_mret <= id_is_mret;
                    id_ex_is_csr <= id_is_csr;
                    id_ex_csr_op <= id_funct3;
                    id_ex_csr_addr <= id_csr_addr;
                    id_ex_csr_zimm <= id_csr_zimm;
                    id_ex_csr_uses_uimm <= id_csr_uses_uimm;
	            end

                if (ex_take_trap) begin
                    csr_mepc <= id_ex_pc;
                    csr_mcause <= ex_trap_cause;
                    csr_mstatus[MSTATUS_MPIE_BIT] <= csr_mstatus[MSTATUS_MIE_BIT];
                    csr_mstatus[MSTATUS_MIE_BIT] <= 1'b0;
                end else if (ex_mret_redirect) begin
                    csr_mstatus[MSTATUS_MIE_BIT] <= csr_mstatus[MSTATUS_MPIE_BIT];
                    csr_mstatus[MSTATUS_MPIE_BIT] <= 1'b1;
                end else if (ex_csr_write_enable) begin
                    case (id_ex_csr_addr)
                        CSR_MSTATUS: csr_mstatus <= ex_csr_write_data;
                        CSR_MIE:     csr_mie <= ex_csr_write_data;
                        CSR_MTVEC:   csr_mtvec <= {ex_csr_write_data[31:2], 2'b00};
                        CSR_MEPC:    csr_mepc <= {ex_csr_write_data[31:2], 2'b00};
                        CSR_MCAUSE:  csr_mcause <= ex_csr_write_data;
                        default: begin
                            csr_mstatus <= csr_mstatus;
                        end
                    endcase
                end

	            ex_mem_valid <= id_ex_valid && !ex_kill_current;
	            ex_mem_aluout <= ex_exec_result;
	            ex_mem_store_data <= ex_src_b_raw;
	            ex_mem_pc4 <= id_ex_pc4;
	            ex_mem_rd <= id_ex_rd;
	            ex_mem_regwrite <= id_ex_valid && !ex_kill_current && id_ex_regwrite;
	            ex_mem_memwrite <= id_ex_valid && !ex_kill_current && id_ex_memwrite;
	            ex_mem_wdsel <= id_ex_wdsel;
	            ex_mem_dm_ctrl <= id_ex_dm_ctrl;

            mem_wb_valid <= ex_mem_valid;
            mem_wb_mem_data <= Data_in;
            mem_wb_aluout <= ex_mem_aluout;
            mem_wb_pc4 <= ex_mem_pc4;
	            mem_wb_rd <= ex_mem_rd;
	            mem_wb_regwrite <= ex_mem_valid && ex_mem_regwrite;
	            mem_wb_wdsel <= ex_mem_wdsel;
                end
	        end
	    end
endmodule

`default_nettype wire
