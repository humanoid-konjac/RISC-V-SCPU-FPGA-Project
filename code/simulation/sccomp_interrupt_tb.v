`timescale 1ns/1ps

module sccomp_interrupt_tb();
   localparam [31:0] DONE_PC = 32'h0000_003c;

   reg         clk;
   reg         rstn;
   reg         irq;
   wire [31:0] instr;
   wire [31:0] PC;
   wire        MemWrite;
   wire [2:0]  DMType;
   wire [31:0] dm_addr;
   wire [31:0] dm_din;
   wire [31:0] dm_dout;
   wire        CPU_MIO;

   reg [31:0] imem[0:127];
   integer i;
   integer counter;
   integer done_wait;
   integer errors;

   wire rst = ~rstn;

   assign instr = imem[PC[8:2]];

   SCPU U_SCPU(
      .clk(clk),
      .reset(rst),
      .en(1'b1),
      .MIO_ready(1'b1),
      .inst_in(instr),
      .Data_in(dm_dout),
      .mem_w(MemWrite),
      .PC_out(PC),
      .Addr_out(dm_addr),
      .dm_ctrl(DMType),
      .Data_out(dm_din),
      .CPU_MIO(CPU_MIO),
      .INT(irq)
   );

   dm U_DM(
      .clk(clk),
      .DMWr(MemWrite),
      .DMType(DMType),
      .addr(dm_addr),
      .din(dm_din),
      .dout(dm_dout)
   );

   function [31:0] dmem_word;
      input integer addr;
      begin
         dmem_word = {U_DM.dmem[addr + 3], U_DM.dmem[addr + 2],
                      U_DM.dmem[addr + 1], U_DM.dmem[addr]};
      end
   endfunction

   task check32;
      input [255:0] name;
      input [31:0]  got;
      input [31:0]  expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%h expected=%h", name, got, expected);
         end
      end
   endtask

   task load_program;
      begin
         for (i = 0; i < 128; i = i + 1)
            imem[i] = 32'h0000_0013;

         imem[  0] = 32'h0010_0093; // 000: addi x1,x0,1
         imem[  1] = 32'h1000_0113; // 004: addi x2,x0,0x100
         imem[  2] = 32'h3051_1073; // 008: csrw mtvec,x2
         imem[  3] = 32'h0000_0073; // 00c: ecall
         imem[  4] = 32'h00a0_0513; // 010: addi x10,x0,10
         imem[  5] = 32'h00a0_3623; // 014: illegal store funct3=011
         imem[  6] = 32'h00b0_0593; // 018: addi x11,x0,11
         imem[  7] = 32'h0205_0733; // 01c: illegal R-type, would write x14
         imem[  8] = 32'h00c0_0613; // 020: addi x12,x0,12
         imem[  9] = 32'h0800_0193; // 024: addi x3,x0,128
         imem[ 10] = 32'h3041_a073; // 028: csrs mie,x3
         imem[ 11] = 32'h0080_0193; // 02c: addi x3,x0,8
         imem[ 12] = 32'h3001_a073; // 030: csrs mstatus,x3
         imem[ 13] = 32'h00d0_0693; // 034: addi x13,x0,13
         imem[ 14] = 32'h00f0_0793; // 038: addi x15,x0,15
         imem[ 15] = 32'h0000_006f; // 03c: jal x0,0

         imem[ 64] = 32'h3420_22f3; // 100: csrr x5,mcause
         imem[ 65] = 32'h0020_0313; // 104: addi x6,x0,2
         imem[ 66] = 32'h0262_8463; // 108: beq x5,x6,illegal
         imem[ 67] = 32'h00b0_0313; // 10c: addi x6,x0,11
         imem[ 68] = 32'h0062_8663; // 110: beq x5,x6,ecall
         imem[ 69] = 32'h0050_2423; // 114: timer: sw x5,8(x0)
         imem[ 70] = 32'h3020_0073; // 118: mret
         imem[ 71] = 32'h0050_2023; // 11c: ecall: sw x5,0(x0)
         imem[ 72] = 32'h3410_23f3; // 120: csrr x7,mepc
         imem[ 73] = 32'h0043_8393; // 124: addi x7,x7,4
         imem[ 74] = 32'h3413_9073; // 128: csrw mepc,x7
         imem[ 75] = 32'h3020_0073; // 12c: mret
         imem[ 76] = 32'h0050_2223; // 130: illegal: sw x5,4(x0)
         imem[ 77] = 32'h3410_23f3; // 134: csrr x7,mepc
         imem[ 78] = 32'h0043_8393; // 138: addi x7,x7,4
         imem[ 79] = 32'h3413_9073; // 13c: csrw mepc,x7
         imem[ 80] = 32'h3020_0073; // 140: mret
      end
   endtask

   task check_results;
      begin
         check32("x1/start", U_SCPU.U_RF.rf[1], 32'h0000_0001);
         check32("x10/after ecall", U_SCPU.U_RF.rf[10], 32'h0000_000a);
         check32("x11/after illegal store", U_SCPU.U_RF.rf[11], 32'h0000_000b);
         check32("x12/after illegal rtype", U_SCPU.U_RF.rf[12], 32'h0000_000c);
         check32("x13/timer return", U_SCPU.U_RF.rf[13], 32'h0000_000d);
         check32("x14/illegal rtype killed", U_SCPU.U_RF.rf[14], 32'h0000_0000);
         check32("x15/done", U_SCPU.U_RF.rf[15], 32'h0000_000f);

         check32("ecall mcause", dmem_word(0), 32'h0000_000b);
         check32("illegal mcause", dmem_word(4), 32'h0000_0002);
         check32("timer mcause", dmem_word(8), 32'h8000_0007);
         check32("illegal store killed", dmem_word(12), 32'h0000_0000);

         check32("mtvec", U_SCPU.csr_mtvec, 32'h0000_0100);
         check32("timer pending cleared", {31'b0, U_SCPU.timer_irq_pending}, 32'h0000_0000);
      end
   endtask

   initial begin
      load_program();
      $dumpfile("sim_out/sccomp_interrupt.vcd");
      $dumpvars(0, sccomp_interrupt_tb);

      clk = 1'b1;
      rstn = 1'b1;
      irq = 1'b0;
      counter = 0;
      done_wait = -1;
      errors = 0;

      #5;
      rstn = 1'b0;
      #20;
      rstn = 1'b1;

      #250;
      irq = 1'b1;
      #100;
      irq = 1'b0;
   end

   always #50 clk = ~clk;

   always @(posedge clk) begin
      #1;
      if (rstn) begin
         counter = counter + 1;

         if (PC === 32'hxxxx_xxxx) begin
            $display("FAIL: PC became unknown");
            $finish;
         end

         if (counter == 2000) begin
            $display("FAIL: interrupt simulation timeout");
            $finish;
         end

         if ((done_wait < 0) && (PC == DONE_PC) &&
             (dmem_word(8) == 32'h8000_0007))
            done_wait = 0;
         else if (done_wait >= 0)
            done_wait = done_wait + 1;

         if (done_wait == 8) begin
            check_results();

            if (errors == 0)
               $display("PASS: interrupt/exception test completed");
            else
               $display("FAIL: interrupt/exception test completed with %0d error(s)", errors);

            $finish;
         end
      end
   end
endmodule
