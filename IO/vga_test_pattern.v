`timescale 1ns / 1ps
`default_nettype none

module vga_test_pattern(
    input  wire       clk,
    input  wire       rst,
    input  wire       pixel_tick,
    input  wire       active_video,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       enable_sprite,
    input  wire       move_up,
    input  wire       move_down,
    input  wire       move_left,
    input  wire       move_right,
    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b,
    output reg  [9:0] sprite_x,
    output reg  [9:0] sprite_y
);
    localparam SCREEN_W    = 10'd640;
    localparam SCREEN_H    = 10'd480;
    localparam SPRITE_SIZE = 10'd32;
    localparam MOVE_STEP   = 10'd8;
    localparam SPRITE_X0   = 10'd304;
    localparam SPRITE_Y0   = 10'd224;

    wire sprite_on = enable_sprite &&
                     active_video &&
                     (pixel_x >= sprite_x) &&
                     (pixel_x < sprite_x + SPRITE_SIZE) &&
                     (pixel_y >= sprite_y) &&
                     (pixel_y < sprite_y + SPRITE_SIZE);

    wire sprite_border = sprite_on &&
                         ((pixel_x < sprite_x + 10'd3) ||
                          (pixel_x >= sprite_x + SPRITE_SIZE - 10'd3) ||
                          (pixel_y < sprite_y + 10'd3) ||
                          (pixel_y >= sprite_y + SPRITE_SIZE - 10'd3));

    wire screen_border = active_video &&
                         ((pixel_x < 10'd4) ||
                          (pixel_x >= SCREEN_W - 10'd4) ||
                          (pixel_y < 10'd4) ||
                          (pixel_y >= SCREEN_H - 10'd4));

    wire center_line = active_video &&
                       ((pixel_x == 10'd319) ||
                        (pixel_x == 10'd320) ||
                        (pixel_y == 10'd239) ||
                        (pixel_y == 10'd240));

    reg [11:0] pattern_rgb;

    always @(*) begin
        if (!active_video)
            pattern_rgb = 12'h000;
        else if (sprite_border)
            pattern_rgb = 12'hfff;
        else if (sprite_on)
            pattern_rgb = 12'hf80;
        else if (screen_border || center_line)
            pattern_rgb = 12'hfff;
        else if (pixel_x < 10'd80)
            pattern_rgb = 12'hf00;
        else if (pixel_x < 10'd160)
            pattern_rgb = 12'h0f0;
        else if (pixel_x < 10'd240)
            pattern_rgb = 12'h00f;
        else if (pixel_x < 10'd320)
            pattern_rgb = 12'hff0;
        else if (pixel_x < 10'd400)
            pattern_rgb = 12'h0ff;
        else if (pixel_x < 10'd480)
            pattern_rgb = 12'hf0f;
        else if (pixel_x < 10'd560)
            pattern_rgb = 12'h888;
        else
            pattern_rgb = 12'h222;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sprite_x <= SPRITE_X0;
            sprite_y <= SPRITE_Y0;
        end else begin
            if (move_left) begin
                if (sprite_x <= MOVE_STEP)
                    sprite_x <= 10'd0;
                else
                    sprite_x <= sprite_x - MOVE_STEP;
            end else if (move_right) begin
                if (sprite_x >= SCREEN_W - SPRITE_SIZE - MOVE_STEP)
                    sprite_x <= SCREEN_W - SPRITE_SIZE;
                else
                    sprite_x <= sprite_x + MOVE_STEP;
            end

            if (move_up) begin
                if (sprite_y <= MOVE_STEP)
                    sprite_y <= 10'd0;
                else
                    sprite_y <= sprite_y - MOVE_STEP;
            end else if (move_down) begin
                if (sprite_y >= SCREEN_H - SPRITE_SIZE - MOVE_STEP)
                    sprite_y <= SCREEN_H - SPRITE_SIZE;
                else
                    sprite_y <= sprite_y + MOVE_STEP;
            end
        end
    end

    always @(*) begin
        if (rst) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end else begin
            vga_r = pattern_rgb[11:8];
            vga_g = pattern_rgb[7:4];
            vga_b = pattern_rgb[3:0];
        end
    end
endmodule

`default_nettype wire
