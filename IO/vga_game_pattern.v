`timescale 1ns / 1ps
`default_nettype none

module vga_game_pattern(
    input  wire         clk,
    input  wire         rst,
    input  wire         frame_tick,
    input  wire         active_video,
    input  wire [9:0]   pixel_x,
    input  wire [9:0]   pixel_y,
    input  wire [255:0] active_tubes,
    input  wire [31:0]  active_ui,
    output reg  [3:0]   vga_r,
    output reg  [3:0]   vga_g,
    output reg  [3:0]   vga_b
);
    localparam [9:0] TUBE_X0       = 10'd44;
    localparam [9:0] TUBE_STRIDE   = 10'd70;
    localparam [9:0] TUBE_WIDTH    = 10'd48;
    localparam [9:0] TUBE_TOP      = 10'd100;
    localparam [9:0] TUBE_BOTTOM   = 10'd356;
    localparam [9:0] WALL_WIDTH    = 10'd4;
    localparam [9:0] LIQUID_LEFT   = 10'd5;
    localparam [9:0] LIQUID_RIGHT  = 10'd43;
    localparam [9:0] LAYER3_TOP    = 10'd112;
    localparam [9:0] LAYER2_TOP    = 10'd172;
    localparam [9:0] LAYER1_TOP    = 10'd232;
    localparam [9:0] LAYER0_TOP    = 10'd292;
    localparam [9:0] CURSOR_TOP    = 10'd370;
    localparam [9:0] CURSOR_BOTTOM = 10'd378;

    wire [2:0] cursor_index = active_ui[2:0];
    wire [2:0] selected_index = active_ui[6:4];
    wire       selected_valid = active_ui[7];
    wire       game_finished = active_ui[8];

    reg [5:0] frame_counter;
    reg [2:0] tube_index;
    reg [9:0] tube_left;
    reg       tube_span_valid;
    reg [31:0] tube_data;
    reg [1:0] liquid_layer;
    reg       liquid_y_valid;
    reg [3:0] liquid_color;
    reg [11:0] liquid_rgb;
    reg [11:0] pixel_rgb;

    wire tube_vertical_span = tube_span_valid &&
                              (pixel_y >= TUBE_TOP) &&
                              (pixel_y < TUBE_BOTTOM);
    wire tube_wall_on = tube_vertical_span &&
                        ((pixel_x < tube_left + WALL_WIDTH) ||
                         (pixel_x >= tube_left + TUBE_WIDTH - WALL_WIDTH) ||
                         (pixel_y >= TUBE_BOTTOM - WALL_WIDTH));
    wire liquid_x_valid = tube_span_valid &&
                          (pixel_x >= tube_left + LIQUID_LEFT) &&
                          (pixel_x < tube_left + LIQUID_RIGHT);
    wire liquid_on = liquid_x_valid && liquid_y_valid &&
                     (liquid_color != 4'd0);
    wire cursor_on = tube_span_valid &&
                     (tube_index == cursor_index) &&
                     (pixel_y >= CURSOR_TOP) &&
                     (pixel_y < CURSOR_BOTTOM);
    wire selected_on = selected_valid && tube_span_valid &&
                       (tube_index == selected_index);
    wire screen_border = (pixel_x < 10'd8) || (pixel_x >= 10'd632) ||
                         (pixel_y < 10'd8) || (pixel_y >= 10'd472);
    wire win_flash_on = game_finished && !frame_counter[5] && screen_border;

    always @(posedge clk or posedge rst) begin
        if (rst)
            frame_counter <= 6'b0;
        else if (frame_tick)
            frame_counter <= frame_counter + 6'd1;
    end

    always @(*) begin
        tube_index = 3'd0;
        tube_left = TUBE_X0;
        tube_span_valid = 1'b1;

        if ((pixel_x >= TUBE_X0) && (pixel_x < TUBE_X0 + TUBE_WIDTH)) begin
            tube_index = 3'd0;
            tube_left = TUBE_X0;
        end else if ((pixel_x >= TUBE_X0 + TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd1;
            tube_left = TUBE_X0 + TUBE_STRIDE;
        end else if ((pixel_x >= TUBE_X0 + 2 * TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + 2 * TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd2;
            tube_left = TUBE_X0 + 2 * TUBE_STRIDE;
        end else if ((pixel_x >= TUBE_X0 + 3 * TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + 3 * TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd3;
            tube_left = TUBE_X0 + 3 * TUBE_STRIDE;
        end else if ((pixel_x >= TUBE_X0 + 4 * TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + 4 * TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd4;
            tube_left = TUBE_X0 + 4 * TUBE_STRIDE;
        end else if ((pixel_x >= TUBE_X0 + 5 * TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + 5 * TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd5;
            tube_left = TUBE_X0 + 5 * TUBE_STRIDE;
        end else if ((pixel_x >= TUBE_X0 + 6 * TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + 6 * TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd6;
            tube_left = TUBE_X0 + 6 * TUBE_STRIDE;
        end else if ((pixel_x >= TUBE_X0 + 7 * TUBE_STRIDE) &&
                     (pixel_x < TUBE_X0 + 7 * TUBE_STRIDE + TUBE_WIDTH)) begin
            tube_index = 3'd7;
            tube_left = TUBE_X0 + 7 * TUBE_STRIDE;
        end else begin
            tube_span_valid = 1'b0;
        end
    end

    always @(*) begin
        case (tube_index)
            3'd0: tube_data = active_tubes[31:0];
            3'd1: tube_data = active_tubes[63:32];
            3'd2: tube_data = active_tubes[95:64];
            3'd3: tube_data = active_tubes[127:96];
            3'd4: tube_data = active_tubes[159:128];
            3'd5: tube_data = active_tubes[191:160];
            3'd6: tube_data = active_tubes[223:192];
            default: tube_data = active_tubes[255:224];
        endcase
    end

    always @(*) begin
        liquid_layer = 2'd0;
        liquid_y_valid = 1'b1;
        if ((pixel_y >= LAYER0_TOP) && (pixel_y < TUBE_BOTTOM - WALL_WIDTH))
            liquid_layer = 2'd0;
        else if ((pixel_y >= LAYER1_TOP) && (pixel_y < LAYER0_TOP))
            liquid_layer = 2'd1;
        else if ((pixel_y >= LAYER2_TOP) && (pixel_y < LAYER1_TOP))
            liquid_layer = 2'd2;
        else if ((pixel_y >= LAYER3_TOP) && (pixel_y < LAYER2_TOP))
            liquid_layer = 2'd3;
        else
            liquid_y_valid = 1'b0;

        case (liquid_layer)
            2'd0: liquid_color = tube_data[3:0];
            2'd1: liquid_color = tube_data[7:4];
            2'd2: liquid_color = tube_data[11:8];
            default: liquid_color = tube_data[15:12];
        endcase
    end

    always @(*) begin
        case (liquid_color)
            4'd1: liquid_rgb = 12'hf33;
            4'd2: liquid_rgb = 12'h3d3;
            4'd3: liquid_rgb = 12'h36f;
            4'd4: liquid_rgb = 12'hfd2;
            4'd5: liquid_rgb = 12'hb4f;
            4'd6: liquid_rgb = 12'h3dd;
            default: liquid_rgb = 12'h123;
        endcase
    end

    always @(*) begin
        if (rst || !active_video)
            pixel_rgb = 12'h000;
        else if (win_flash_on)
            pixel_rgb = 12'h3f3;
        else if (cursor_on)
            pixel_rgb = 12'hfff;
        else if (tube_wall_on)
            pixel_rgb = selected_on ? 12'hff0 : 12'hccc;
        else if (liquid_on)
            pixel_rgb = liquid_rgb;
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
