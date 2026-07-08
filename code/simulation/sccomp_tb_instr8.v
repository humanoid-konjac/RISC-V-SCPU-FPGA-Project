`timescale 1ns/1ps

module sccomp_tb_instr8();

   localparam [31:0] CHECK_PC = 32'h00000108;

   reg         clk;
   reg         rstn;
   reg  [4:0] reg_sel;
   wire [31:0] reg_data;

   integer foutput;
   integer counter;
   integer errors;
   integer init_i;

   sccomp U_SCCOMP(
      .clk(clk),
      .rstn(rstn),
      .reg_sel(reg_sel),
      .reg_data(reg_data)
   );

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

   task check8;
      input [255:0] name;
      input [7:0]   got;
      input [7:0]   expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%02h expected=%02h", name, got, expected);
         end
      end
   endtask

   task dump_regs_and_mem;
      begin
         $fdisplay(foutput, "pc:\t %h", U_SCCOMP.PC);
         $fdisplay(foutput, "instr:\t\t %h", U_SCCOMP.instr);
         $fdisplay(foutput, "rf00-03:\t %h %h %h %h", 0, U_SCCOMP.U_SCPU.U_RF.rf[1], U_SCCOMP.U_SCPU.U_RF.rf[2], U_SCCOMP.U_SCPU.U_RF.rf[3]);
         $fdisplay(foutput, "rf04-07:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[4], U_SCCOMP.U_SCPU.U_RF.rf[5], U_SCCOMP.U_SCPU.U_RF.rf[6], U_SCCOMP.U_SCPU.U_RF.rf[7]);
         $fdisplay(foutput, "rf08-11:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[8], U_SCCOMP.U_SCPU.U_RF.rf[9], U_SCCOMP.U_SCPU.U_RF.rf[10], U_SCCOMP.U_SCPU.U_RF.rf[11]);
         $fdisplay(foutput, "rf12-15:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[12], U_SCCOMP.U_SCPU.U_RF.rf[13], U_SCCOMP.U_SCPU.U_RF.rf[14], U_SCCOMP.U_SCPU.U_RF.rf[15]);
         $fdisplay(foutput, "rf16-19:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[16], U_SCCOMP.U_SCPU.U_RF.rf[17], U_SCCOMP.U_SCPU.U_RF.rf[18], U_SCCOMP.U_SCPU.U_RF.rf[19]);
         $fdisplay(foutput, "rf20-23:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[20], U_SCCOMP.U_SCPU.U_RF.rf[21], U_SCCOMP.U_SCPU.U_RF.rf[22], U_SCCOMP.U_SCPU.U_RF.rf[23]);
         $fdisplay(foutput, "rf24-27:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[24], U_SCCOMP.U_SCPU.U_RF.rf[25], U_SCCOMP.U_SCPU.U_RF.rf[26], U_SCCOMP.U_SCPU.U_RF.rf[27]);
         $fdisplay(foutput, "rf28-31:\t %h %h %h %h", U_SCCOMP.U_SCPU.U_RF.rf[28], U_SCCOMP.U_SCPU.U_RF.rf[29], U_SCCOMP.U_SCPU.U_RF.rf[30], U_SCCOMP.U_SCPU.U_RF.rf[31]);
         $fdisplay(foutput, "mem00-07:\t %02h %02h %02h %02h %02h %02h %02h %02h",
                   U_SCCOMP.U_DM.dmem[0], U_SCCOMP.U_DM.dmem[1], U_SCCOMP.U_DM.dmem[2], U_SCCOMP.U_DM.dmem[3],
                   U_SCCOMP.U_DM.dmem[4], U_SCCOMP.U_DM.dmem[5], U_SCCOMP.U_DM.dmem[6], U_SCCOMP.U_DM.dmem[7]);
         $fdisplay(foutput, "mem08-15:\t %02h %02h %02h %02h %02h %02h %02h %02h",
                   U_SCCOMP.U_DM.dmem[8], U_SCCOMP.U_DM.dmem[9], U_SCCOMP.U_DM.dmem[10], U_SCCOMP.U_DM.dmem[11],
                   U_SCCOMP.U_DM.dmem[12], U_SCCOMP.U_DM.dmem[13], U_SCCOMP.U_DM.dmem[14], U_SCCOMP.U_DM.dmem[15]);
         $fdisplay(foutput, "mem16-23:\t %02h %02h %02h %02h %02h %02h %02h %02h",
                   U_SCCOMP.U_DM.dmem[16], U_SCCOMP.U_DM.dmem[17], U_SCCOMP.U_DM.dmem[18], U_SCCOMP.U_DM.dmem[19],
                   U_SCCOMP.U_DM.dmem[20], U_SCCOMP.U_DM.dmem[21], U_SCCOMP.U_DM.dmem[22], U_SCCOMP.U_DM.dmem[23]);
         $fdisplay(foutput, "mem24-35:\t %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h",
                   U_SCCOMP.U_DM.dmem[24], U_SCCOMP.U_DM.dmem[25], U_SCCOMP.U_DM.dmem[26], U_SCCOMP.U_DM.dmem[27],
                   U_SCCOMP.U_DM.dmem[28], U_SCCOMP.U_DM.dmem[29], U_SCCOMP.U_DM.dmem[30], U_SCCOMP.U_DM.dmem[31],
                   U_SCCOMP.U_DM.dmem[32], U_SCCOMP.U_DM.dmem[33], U_SCCOMP.U_DM.dmem[34], U_SCCOMP.U_DM.dmem[35]);
      end
   endtask

   task check_results;
      begin
         check32("x1/jal link",      U_SCCOMP.U_SCPU.U_RF.rf[1],  32'h00000108);
         check32("x3/base",          U_SCCOMP.U_SCPU.U_RF.rf[3],  32'h00000000);
         check32("x4/sltiu",         U_SCCOMP.U_SCPU.U_RF.rf[4],  32'h00000001);
         check32("x5/lw",            U_SCCOMP.U_SCPU.U_RF.rf[5],  32'h98763bcb);
         check32("x6/lui",           U_SCCOMP.U_SCPU.U_RF.rf[6],  32'h98765000);
         check32("x7/lhu",           U_SCCOMP.U_SCPU.U_RF.rf[7],  32'h00009876);
         check32("x8/lbu",           U_SCCOMP.U_SCPU.U_RF.rf[8],  32'h0000003b);
         check32("x9/branch result", U_SCCOMP.U_SCPU.U_RF.rf[9],  32'h0000000e);
         check32("x10/jal body",     U_SCCOMP.U_SCPU.U_RF.rf[10], 32'h000007af);
         check32("x18/andi",         U_SCCOMP.U_SCPU.U_RF.rf[18], 32'h00000301);
         check32("x19/sub",          U_SCCOMP.U_SCPU.U_RF.rf[19], 32'h98763bcb);
         check32("x20/slti",         U_SCCOMP.U_SCPU.U_RF.rf[20], 32'h00000001);
         check32("x21/xor",          U_SCCOMP.U_SCPU.U_RF.rf[21], 32'h98765001);
         check32("x22/add",          U_SCCOMP.U_SCPU.U_RF.rf[22], 32'h98766437);
         check32("x23/sub",          U_SCCOMP.U_SCPU.U_RF.rf[23], 32'h00001437);
         check32("x25/or",           U_SCCOMP.U_SCPU.U_RF.rf[25], 32'h98767437);
         check32("x26/and",          U_SCCOMP.U_SCPU.U_RF.rf[26], 32'h00000437);
         check32("x27/slli",         U_SCCOMP.U_SCPU.U_RF.rf[27], 32'hcb000000);
         check32("x28/srli",         U_SCCOMP.U_SCPU.U_RF.rf[28], 32'h098763bc);
         check32("x29/srai",         U_SCCOMP.U_SCPU.U_RF.rf[29], 32'hf98763bc);

         check8("mem[0]",  U_SCCOMP.U_DM.dmem[0],  8'haf);
         check8("mem[1]",  U_SCCOMP.U_DM.dmem[1],  8'h07);
         check8("mem[2]",  U_SCCOMP.U_DM.dmem[2],  8'h00);
         check8("mem[3]",  U_SCCOMP.U_DM.dmem[3],  8'h00);
         check8("mem[12]", U_SCCOMP.U_DM.dmem[12], 8'hcb);
         check8("mem[13]", U_SCCOMP.U_DM.dmem[13], 8'h3b);
         check8("mem[14]", U_SCCOMP.U_DM.dmem[14], 8'h76);
         check8("mem[15]", U_SCCOMP.U_DM.dmem[15], 8'h98);
         check8("mem[16]", U_SCCOMP.U_DM.dmem[16], 8'h76);
         check8("mem[17]", U_SCCOMP.U_DM.dmem[17], 8'h98);
         check8("mem[18]", U_SCCOMP.U_DM.dmem[18], 8'hff);
         check8("mem[19]", U_SCCOMP.U_DM.dmem[19], 8'hff);
         check8("mem[20]", U_SCCOMP.U_DM.dmem[20], 8'h76);
         check8("mem[21]", U_SCCOMP.U_DM.dmem[21], 8'h98);
         check8("mem[24]", U_SCCOMP.U_DM.dmem[24], 8'h98);
         check8("mem[25]", U_SCCOMP.U_DM.dmem[25], 8'hff);
         check8("mem[28]", U_SCCOMP.U_DM.dmem[28], 8'h98);
         check8("mem[32]", U_SCCOMP.U_DM.dmem[32], 8'h3b);

         reg_sel = 5'd10;
         #1;
         check32("reg_data(x10)", reg_data, 32'h000007af);
      end
   endtask

   initial begin
      $dumpfile("sim_out/sccomp_instr8.vcd");
      $dumpvars(0, sccomp_tb_instr8);

      for (init_i = 0; init_i < 128; init_i = init_i + 1)
         U_SCCOMP.U_IM.ROM[init_i] = 32'h00000013;
      $readmemh("Test_37_Instr8.dat", U_SCCOMP.U_IM.ROM, 0, 70);
      foutput = $fopen("sim_out/results_instr8.txt", "w");

      clk = 1'b1;
      rstn = 1'b1;
      reg_sel = 5'd0;
      counter = 0;
      errors = 0;

      #5;
      rstn = 1'b0;
      #20;
      rstn = 1'b1;
   end

   always #50 clk = ~clk;

   always @(posedge clk) begin
      #1;
      if (rstn) begin
         counter = counter + 1;

         if (U_SCCOMP.U_SCPU.PC_out === 32'hxxxxxxxx) begin
            $display("FAIL: PC became unknown");
            $fclose(foutput);
            $finish;
         end

         if (counter == 1000) begin
            $display("FAIL: simulation timeout");
            $fclose(foutput);
            $finish;
         end

         if (U_SCCOMP.PC == CHECK_PC) begin
            dump_regs_and_mem();
            check_results();

            if (errors == 0)
               $display("PASS: Test_37_Instr8 reached first jalr return");
            else
               $display("FAIL: Test_37_Instr8 completed with %0d error(s)", errors);

            $fclose(foutput);
            $finish;
         end
      end
   end

endmodule
