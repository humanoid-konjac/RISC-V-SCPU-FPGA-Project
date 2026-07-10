`timescale 1ns / 1ps
`default_nettype none

module vga_game_pattern(
    input  wire         rst,
    input  wire         active_video,
    input  wire [9:0]   pixel_x,
    input  wire [9:0]   pixel_y,
    input  wire [255:0] active_tubes,
    output reg  [3:0]   vga_r,
    output reg  [3:0]   vga_g,
    output reg  [3:0]   vga_b
);
    localparam [9:0] BLOCK_LEFT   = 10'd256;
    localparam [9:0] BLOCK_RIGHT  = 10'd384;
    localparam [9:0] BLOCK_TOP    = 10'd176;
    localparam [9:0] BLOCK_BOTTOM = 10'd304;
    localparam [9:0] BORDER       = 10'd4;

    wire [3:0] color_index = active_tubes[3:0];
    wire block_on = (pixel_x >= BLOCK_LEFT) && (pixel_x < BLOCK_RIGHT) &&
                    (pixel_y >= BLOCK_TOP) && (pixel_y < BLOCK_BOTTOM);
    wire border_on = block_on &&
                     ((pixel_x < BLOCK_LEFT + BORDER) ||
                      (pixel_x >= BLOCK_RIGHT - BORDER) ||
                      (pixel_y < BLOCK_TOP + BORDER) ||
                      (pixel_y >= BLOCK_BOTTOM - BORDER));

    reg [11:0] color_rgb;
    reg [11:0] pixel_rgb;

    always @(*) begin
        case (color_index)
            4'd1: color_rgb = 12'hf33;
            4'd2: color_rgb = 12'h3d3;
            4'd3: color_rgb = 12'h36f;
            4'd4: color_rgb = 12'hfd2;
            4'd5: color_rgb = 12'hb4f;
            4'd6: color_rgb = 12'h3dd;
            default: color_rgb = 12'h222;
        endcase
    end

    always @(*) begin
        if (rst || !active_video)
            pixel_rgb = 12'h000;
        else if (border_on)
            pixel_rgb = 12'hfff;
        else if (block_on)
            pixel_rgb = color_rgb;
        else
            pixel_rgb = 12'h123;
    end

    always @(*) begin
        vga_r = pixel_rgb[11:8];
        vga_g = pixel_rgb[7:4];
        vga_b = pixel_rgb[3:0];
    end
endmodule

`default_nettype wire
