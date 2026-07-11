`timescale 1ns/1ps

module ROM_D(
    input  wire [9:0]  a,
    output wire [31:0] spo
);
    assign spo = 32'b0;
endmodule

module RAM_B(
    input  wire [9:0]  addra,
    input  wire        clka,
    input  wire [31:0] dina,
    input  wire [3:0]  wea,
    output wire [31:0] douta
);
    assign douta = 32'b0;
endmodule
