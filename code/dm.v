`timescale 1ns/1ps

`include "ctrl_encode_def.v"

// byte-addressed data memory, little endian
module dm(clk, DMWr, DMType, addr, din, dout);
   input          clk;
   input          DMWr;
   input  [2:0]   DMType;
   input  [31:0]  addr;
   input  [31:0]  din;
   output [31:0]  dout;

   reg [7:0] dmem[0:511];
   reg [31:0] dout_r;
   integer i;

   wire [8:0] a = addr[8:0];

   initial begin
      for (i = 0; i < 512; i = i + 1)
         dmem[i] = 8'b0;
   end

   always @(posedge clk)
      if (DMWr) begin
         case (DMType)
            `dm_byte: begin
               dmem[a] <= din[7:0];
               $display("dmem[0x%8X] <- byte 0x%2X", addr, din[7:0]);
            end
            `dm_halfword: begin
               dmem[a] <= din[7:0];
               dmem[a + 1] <= din[15:8];
               $display("dmem[0x%8X] <- half 0x%4X", addr, din[15:0]);
            end
            default: begin
               dmem[a] <= din[7:0];
               dmem[a + 1] <= din[15:8];
               dmem[a + 2] <= din[23:16];
               dmem[a + 3] <= din[31:24];
               $display("dmem[0x%8X] <- word 0x%8X", addr, din);
            end
         endcase
      end

   always @(*) begin
      case (DMType)
         `dm_byte:
            dout_r = {{24{dmem[a][7]}}, dmem[a]};
         `dm_byte_unsigned:
            dout_r = {24'b0, dmem[a]};
         `dm_halfword:
            dout_r = {{16{dmem[a + 1][7]}}, dmem[a + 1], dmem[a]};
         `dm_halfword_unsigned:
            dout_r = {16'b0, dmem[a + 1], dmem[a]};
         default:
            dout_r = {dmem[a + 3], dmem[a + 2], dmem[a + 1], dmem[a]};
      endcase
   end

   assign dout = dout_r;

endmodule
