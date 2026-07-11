`timescale 1ns / 1ps
`default_nettype none

module vga_output_register(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] rgb_in,
    input  wire        hsync_in,
    input  wire        vsync_in,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output reg         hsync_out,
    output reg         vsync_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
            hsync_out <= 1'b1;
            vsync_out <= 1'b1;
        end else begin
            vga_r <= rgb_in[11:8];
            vga_g <= rgb_in[7:4];
            vga_b <= rgb_in[3:0];
            hsync_out <= hsync_in;
            vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
