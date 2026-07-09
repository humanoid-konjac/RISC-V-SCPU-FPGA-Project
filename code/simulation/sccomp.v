`timescale 1ns/1ps

module sccomp(clk, rstn, reg_sel, reg_data);
   input          clk;
   input          rstn;
   input [4:0]    reg_sel;
   output [31:0]  reg_data;
   
   wire [31:0]    instr;
   wire [31:0]    PC;
   wire           MemWrite;
   wire [2:0]     DMType;
   wire [31:0]    dm_addr, dm_din, dm_dout;
   wire           CPU_MIO;
   
   wire rst = ~rstn;
       
   // instantiation of single-cycle CPU
   SCPU U_SCPU(
      .clk(clk),              // input: cpu clock
      .reset(rst),            // input: reset
      .en(1'b1),              // advance every simulation clock
      .MIO_ready(1'b1),       // unused by this CPU
      .inst_in(instr),        // input: instruction
      .Data_in(dm_dout),      // input: data to cpu
      .mem_w(MemWrite),       // output: memory write signal
      .PC_out(PC),            // output: PC
      .Addr_out(dm_addr),     // output: address from cpu to memory
      .dm_ctrl(DMType),       // output: data memory access type
      .Data_out(dm_din),      // output: data from cpu to memory
      .CPU_MIO(CPU_MIO),      // unused by this test wrapper
      .INT(1'b0)              // unused by this CPU
   );

   assign reg_data = (reg_sel != 0) ? U_SCPU.U_RF.rf[reg_sel] : 32'b0;
         
  // instantiation of data memory  
   dm    U_DM(
         .clk(clk),           // input:  cpu clock
         .DMWr(MemWrite),     // input:  ram write
         .DMType(DMType),      // input:  ram access type
         .addr(dm_addr),       // input:  ram address
         .din(dm_din),        // input:  data to ram
         .dout(dm_dout)       // output: data from ram
         );
         
  // instantiation of intruction memory (used for simulation)
   im    U_IM ( 
      .addr(PC[8:2]),     // input:  rom address
      .dout(instr)        // output: instruction
   );
        
endmodule

