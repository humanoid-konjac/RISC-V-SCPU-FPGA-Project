`timescale 1ns/1ps

module sccomp_tb();

   localparam [31:0] DONE_PC = 32'h000000e4;

   reg         clk;
   reg         rstn;
   reg  [4:0] reg_sel;
   wire [31:0] reg_data;

   integer foutput;
   integer counter;
   integer done_wait;
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

   task dump_regs;
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
         $fdisplay(foutput, "mem00-03:\t %02h %02h %02h %02h", U_SCCOMP.U_DM.dmem[0], U_SCCOMP.U_DM.dmem[1], U_SCCOMP.U_DM.dmem[2], U_SCCOMP.U_DM.dmem[3]);
         $fdisplay(foutput, "mem08-11:\t %02h %02h %02h %02h", U_SCCOMP.U_DM.dmem[8], U_SCCOMP.U_DM.dmem[9], U_SCCOMP.U_DM.dmem[10], U_SCCOMP.U_DM.dmem[11]);
      end
   endtask

   task check_results;
      begin
         check32("x1/lui",       U_SCCOMP.U_SCPU.U_RF.rf[1],  32'h12345000);
         check32("x2/auipc",     U_SCCOMP.U_SCPU.U_RF.rf[2],  32'h00000004);
         check32("x3/addi",      U_SCCOMP.U_SCPU.U_RF.rf[3],  32'h0000000a);
         check32("x4/addi",      U_SCCOMP.U_SCPU.U_RF.rf[4],  32'h00000003);
         check32("x5/add",       U_SCCOMP.U_SCPU.U_RF.rf[5],  32'h0000000d);
         check32("x6/sub",       U_SCCOMP.U_SCPU.U_RF.rf[6],  32'h00000007);
         check32("x7/or",        U_SCCOMP.U_SCPU.U_RF.rf[7],  32'h0000000b);
         check32("x8/and",       U_SCCOMP.U_SCPU.U_RF.rf[8],  32'h00000002);
         check32("x9/ori",       U_SCCOMP.U_SCPU.U_RF.rf[9],  32'h0000000b);
         check32("x10/xor",      U_SCCOMP.U_SCPU.U_RF.rf[10], 32'h00000009);
         check32("x11/xori",     U_SCCOMP.U_SCPU.U_RF.rf[11], 32'h00000009);
         check32("x12/andi",     U_SCCOMP.U_SCPU.U_RF.rf[12], 32'h00000002);
         check32("x13/sll",      U_SCCOMP.U_SCPU.U_RF.rf[13], 32'h00000018);
         check32("x14/sra",      U_SCCOMP.U_SCPU.U_RF.rf[14], 32'hfffffffe);
         check32("x15/srl",      U_SCCOMP.U_SCPU.U_RF.rf[15], 32'h00000002);
         check32("x16/slt",      U_SCCOMP.U_SCPU.U_RF.rf[16], 32'h00000001);
         check32("x17/sltu",     U_SCCOMP.U_SCPU.U_RF.rf[17], 32'h00000001);
         check32("x18/srai",     U_SCCOMP.U_SCPU.U_RF.rf[18], 32'hffffffff);
         check32("x19/slti",     U_SCCOMP.U_SCPU.U_RF.rf[19], 32'h00000001);
         check32("x20/sltiu",    U_SCCOMP.U_SCPU.U_RF.rf[20], 32'h00000001);
         check32("x21/slli",     U_SCCOMP.U_SCPU.U_RF.rf[21], 32'h0000000c);
         check32("x22/srli",     U_SCCOMP.U_SCPU.U_RF.rf[22], 32'h00000004);
         check32("x23/lb",       U_SCCOMP.U_SCPU.U_RF.rf[23], 32'hffffff80);
         check32("x24/lh",       U_SCCOMP.U_SCPU.U_RF.rf[24], 32'hffff8001);
         check32("x25/lbu",      U_SCCOMP.U_SCPU.U_RF.rf[25], 32'h00000080);
         check32("x26/lhu",      U_SCCOMP.U_SCPU.U_RF.rf[26], 32'h00008001);
         check32("x27/lw",       U_SCCOMP.U_SCPU.U_RF.rf[27], 32'h12345678);
         check32("x28/jal link", U_SCCOMP.U_SCPU.U_RF.rf[28], 32'h000000d0);
         check32("x29/jalr link", U_SCCOMP.U_SCPU.U_RF.rf[29], 32'h000000dc);
         check32("x30/fail flag", U_SCCOMP.U_SCPU.U_RF.rf[30], 32'h00000000);
         check32("x31/jalr target", U_SCCOMP.U_SCPU.U_RF.rf[31], 32'h000000e0);

         check8("dmem[0]",  U_SCCOMP.U_DM.dmem[0],  8'h78);
         check8("dmem[1]",  U_SCCOMP.U_DM.dmem[1],  8'h56);
         check8("dmem[2]",  U_SCCOMP.U_DM.dmem[2],  8'h34);
         check8("dmem[3]",  U_SCCOMP.U_DM.dmem[3],  8'h12);
         check8("dmem[8]",  U_SCCOMP.U_DM.dmem[8],  8'h80);
         check8("dmem[10]", U_SCCOMP.U_DM.dmem[10], 8'h01);
         check8("dmem[11]", U_SCCOMP.U_DM.dmem[11], 8'h80);

         reg_sel = 5'd27;
         #1;
         check32("reg_data(x27)", reg_data, 32'h12345678);
      end
   endtask

   initial begin
      $dumpfile("sim_out/sccomp_37.vcd");
      $dumpvars(0, sccomp_tb);

      for (init_i = 0; init_i < 128; init_i = init_i + 1)
         U_SCCOMP.U_IM.ROM[init_i] = 32'h00000013;
      $readmemh("Test_37_Instr.dat", U_SCCOMP.U_IM.ROM, 0, 57);
      foutput = $fopen("sim_out/results_37.txt", "w");

      clk = 1'b1;
      rstn = 1'b1;
      reg_sel = 5'd0;
      counter = 0;
      done_wait = -1;
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

         if ((done_wait < 0) && (U_SCCOMP.PC == DONE_PC))
            done_wait = 0;
         else if (done_wait >= 0)
            done_wait = done_wait + 1;

         if (done_wait == 5) begin
            dump_regs();
            check_results();

            if (errors == 0)
               $display("PASS: Test_37_Instr completed");
            else
               $display("FAIL: Test_37_Instr completed with %0d error(s)", errors);

            $fclose(foutput);
            $finish;
         end
      end
   end

endmodule
