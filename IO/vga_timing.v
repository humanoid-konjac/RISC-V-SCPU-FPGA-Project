`timescale 1ns / 1ps
`default_nettype none

module vga_timing(
    input  wire       clk,
    input  wire       rst,
    output wire       pixel_tick,
    output reg  [9:0] pixel_x,
    output reg  [9:0] pixel_y,
    output wire       active_video,
    output wire       frame_tick,
    output wire       hsync,
    output wire       vsync
);
    localparam H_VISIBLE = 10'd640;
    localparam H_FRONT   = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BACK    = 10'd48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 10'd480;
    localparam V_FRONT   = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BACK    = 10'd33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [1:0] tick_div;

    assign pixel_tick = (tick_div == 2'b00);

    always @(posedge clk or posedge rst) begin
        if (rst)
            tick_div <= 2'b00;
        else
            tick_div <= tick_div + 2'b01;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
        end else if (pixel_tick) begin
            if (pixel_x == H_TOTAL - 1'b1) begin
                pixel_x <= 10'd0;
                if (pixel_y == V_TOTAL - 1'b1)
                    pixel_y <= 10'd0;
                else
                    pixel_y <= pixel_y + 10'd1;
            end else begin
                pixel_x <= pixel_x + 10'd1;
            end
        end
    end

    assign active_video = (pixel_x < H_VISIBLE) && (pixel_y < V_VISIBLE);

    assign hsync = ~((pixel_x >= H_VISIBLE + H_FRONT) &&
                     (pixel_x <  H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((pixel_y >= V_VISIBLE + V_FRONT) &&
                     (pixel_y <  V_VISIBLE + V_FRONT + V_SYNC));

    assign frame_tick = pixel_tick &&
                        (pixel_x == H_TOTAL - 1'b1) &&
                        (pixel_y == V_TOTAL - 1'b1);
endmodule

`default_nettype wire
