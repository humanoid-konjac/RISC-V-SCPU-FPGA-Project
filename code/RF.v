`timescale 1ns/1ps

module RF(
    input  wire        clk,
    input  wire        rst,
    input  wire        RFWr,
    input  wire [4:0]  A1,
    input  wire [4:0]  A2,
    input  wire [4:0]  A3,
    input  wire [31:0] WD,
    input  wire [4:0]  reg_sel,
    output wire [31:0] RD1,
    output wire [31:0] RD2,
    output wire [31:0] reg_data
);
    reg [31:0] rf[31:0];
    integer i;

    always @(negedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 32'b0;
            rf[2] <= 32'h0000_0400;
        end else if (RFWr && A3 != 5'd0) begin
            rf[A3] <= WD;
        end
    end

    assign RD1 = (A1 != 5'd0) ? rf[A1] : 32'b0;
    assign RD2 = (A2 != 5'd0) ? rf[A2] : 32'b0;
    assign reg_data = (reg_sel != 5'd0) ? rf[reg_sel] : 32'b0;
endmodule
