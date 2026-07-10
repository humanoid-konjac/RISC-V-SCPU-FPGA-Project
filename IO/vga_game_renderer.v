`timescale 1ns / 1ps
`default_nettype none

module vga_game_renderer(
    input  wire        rst,
    input  wire        active_video,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [1:0]  game_control,
    input  wire [9:0]  player_y,
    input  wire [9:0]  obstacle_x,
    input  wire [9:0]  gap_y,
    input  wire [15:0] score,
    input  wire [1:0]  lives,
    input  wire        player_hurt,
    input  wire [31:0] frame_sequence,
    input  wire [15:0] mic_level,
    input  wire        mic_calibrated,
    input  wire        mic_event_pending,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);
    localparam [9:0] PLAYER_X = 10'd144;
    localparam [9:0] PLAYER_W = 10'd32;
    localparam [9:0] PLAYER_H = 10'd24;
    localparam [9:0] PIPE_W = 10'd56;
    localparam [9:0] GAP_HALF = 10'd80;
    localparam [9:0] GROUND_Y = 10'd440;

    localparam [3:0] GLYPH_G = 4'd0;
    localparam [3:0] GLYPH_A = 4'd1;
    localparam [3:0] GLYPH_M = 4'd2;
    localparam [3:0] GLYPH_E = 4'd3;
    localparam [3:0] GLYPH_O = 4'd4;
    localparam [3:0] GLYPH_V = 4'd5;
    localparam [3:0] GLYPH_R = 4'd6;
    localparam [3:0] GLYPH_D = 4'd7;
    localparam [3:0] GLYPH_Y = 4'd8;

    wire game_enabled = game_control[0];
    wire waiting = game_control[1] && (lives != 2'd0);
    wire game_over = game_control[1] && (lives == 2'd0);

    function [15:0] bird_body_outer;
        input [3:0] row;
        begin
            case (row)
                4'd0: bird_body_outer = 16'b0000000011100000;
                4'd1: bird_body_outer = 16'b0000001111110000;
                4'd2: bird_body_outer = 16'b0000011111111000;
                4'd3: bird_body_outer = 16'b0000111111111110;
                4'd4: bird_body_outer = 16'b0011111111111111;
                4'd5: bird_body_outer = 16'b0111111111111111;
                4'd6: bird_body_outer = 16'b1111111111111110;
                4'd7: bird_body_outer = 16'b0111111111111100;
                4'd8: bird_body_outer = 16'b0011111111111000;
                4'd9: bird_body_outer = 16'b0001111111110000;
                4'd10: bird_body_outer = 16'b0000111111000000;
                default: bird_body_outer = 16'b0000011100000000;
            endcase
        end
    endfunction

    function [15:0] bird_body_inner;
        input [3:0] row;
        begin
            case (row)
                4'd2: bird_body_inner = 16'b0000001111100000;
                4'd3: bird_body_inner = 16'b0000011111111000;
                4'd4: bird_body_inner = 16'b0000111111111100;
                4'd5: bird_body_inner = 16'b0011111111111100;
                4'd6: bird_body_inner = 16'b0111111111111100;
                4'd7: bird_body_inner = 16'b0011111111111000;
                4'd8: bird_body_inner = 16'b0001111111110000;
                4'd9: bird_body_inner = 16'b0000111111100000;
                default: bird_body_inner = 16'b0;
            endcase
        end
    endfunction

    function [15:0] bird_face;
        input [3:0] row;
        begin
            case (row)
                4'd2: bird_face = 16'b0000000001110000;
                4'd3: bird_face = 16'b0000000001111000;
                4'd4: bird_face = 16'b0000000001111000;
                4'd5: bird_face = 16'b0000000001110000;
                default: bird_face = 16'b0;
            endcase
        end
    endfunction

    function [15:0] bird_wing_outer;
        input [1:0] frame;
        input [3:0] row;
        begin
            bird_wing_outer = 16'b0;
            case (frame)
                2'd0: begin
                    case (row)
                        4'd0: bird_wing_outer = 16'b0000111000000000;
                        4'd1: bird_wing_outer = 16'b0001111100000000;
                        4'd2: bird_wing_outer = 16'b0011111100000000;
                        4'd3: bird_wing_outer = 16'b0011111110000000;
                        4'd4: bird_wing_outer = 16'b0001111110000000;
                        4'd5: bird_wing_outer = 16'b0000111110000000;
                        default: bird_wing_outer = 16'b0;
                    endcase
                end
                2'd2: begin
                    case (row)
                        4'd5: bird_wing_outer = 16'b0001111110000000;
                        4'd6: bird_wing_outer = 16'b0011111110000000;
                        4'd7: bird_wing_outer = 16'b0011111100000000;
                        4'd8: bird_wing_outer = 16'b0001111100000000;
                        4'd9: bird_wing_outer = 16'b0001111000000000;
                        4'd10: bird_wing_outer = 16'b0000111000000000;
                        4'd11: bird_wing_outer = 16'b0000010000000000;
                        default: bird_wing_outer = 16'b0;
                    endcase
                end
                default: begin
                    case (row)
                        4'd3: bird_wing_outer = 16'b0011111100000000;
                        4'd4: bird_wing_outer = 16'b0111111110000000;
                        4'd5: bird_wing_outer = 16'b1111111110000000;
                        4'd6: bird_wing_outer = 16'b0111111110000000;
                        4'd7: bird_wing_outer = 16'b0011111100000000;
                        4'd8: bird_wing_outer = 16'b0001111000000000;
                        default: bird_wing_outer = 16'b0;
                    endcase
                end
            endcase
        end
    endfunction

    function [15:0] bird_wing_inner;
        input [1:0] frame;
        input [3:0] row;
        reg [15:0] outer;
        begin
            outer = bird_wing_outer(frame, row);
            bird_wing_inner = (outer >> 1) & outer;
        end
    endfunction

    function [6:0] seven_mask;
        input [3:0] digit;
        begin
            case (digit)
                4'h0: seven_mask = 7'b1111110;
                4'h1: seven_mask = 7'b0110000;
                4'h2: seven_mask = 7'b1101101;
                4'h3: seven_mask = 7'b1111001;
                4'h4: seven_mask = 7'b0110011;
                4'h5: seven_mask = 7'b1011011;
                4'h6: seven_mask = 7'b1011111;
                4'h7: seven_mask = 7'b1110000;
                4'h8: seven_mask = 7'b1111111;
                4'h9: seven_mask = 7'b1111011;
                4'ha: seven_mask = 7'b1110111;
                4'hb: seven_mask = 7'b0011111;
                4'hc: seven_mask = 7'b1001110;
                4'hd: seven_mask = 7'b0111101;
                4'he: seven_mask = 7'b1001111;
                default: seven_mask = 7'b1000111;
            endcase
        end
    endfunction

    function seven_pixel;
        input [3:0] digit;
        input [4:0] local_x;
        input [4:0] local_y;
        reg [6:0] mask;
        begin
            mask = seven_mask(digit);
            seven_pixel =
                (mask[6] && (local_x >= 5'd3) && (local_x < 5'd15) &&
                 (local_y < 5'd3)) ||
                (mask[5] && (local_x >= 5'd14) &&
                 (local_y >= 5'd2) && (local_y < 5'd13)) ||
                (mask[4] && (local_x >= 5'd14) &&
                 (local_y >= 5'd14) && (local_y < 5'd25)) ||
                (mask[3] && (local_x >= 5'd3) && (local_x < 5'd15) &&
                 (local_y >= 5'd24) && (local_y < 5'd27)) ||
                (mask[2] && (local_x < 5'd3) &&
                 (local_y >= 5'd14) && (local_y < 5'd25)) ||
                (mask[1] && (local_x < 5'd3) &&
                 (local_y >= 5'd2) && (local_y < 5'd13)) ||
                (mask[0] && (local_x >= 5'd3) && (local_x < 5'd15) &&
                 (local_y >= 5'd12) && (local_y < 5'd15));
        end
    endfunction

    function [34:0] glyph_bits;
        input [3:0] glyph;
        begin
            case (glyph)
                GLYPH_G: glyph_bits = {5'b01110,5'b10001,5'b10000,5'b10111,
                                       5'b10001,5'b10001,5'b01110};
                GLYPH_A: glyph_bits = {5'b01110,5'b10001,5'b10001,5'b11111,
                                       5'b10001,5'b10001,5'b10001};
                GLYPH_M: glyph_bits = {5'b10001,5'b11011,5'b10101,5'b10101,
                                       5'b10001,5'b10001,5'b10001};
                GLYPH_E: glyph_bits = {5'b11111,5'b10000,5'b10000,5'b11110,
                                       5'b10000,5'b10000,5'b11111};
                GLYPH_O: glyph_bits = {5'b01110,5'b10001,5'b10001,5'b10001,
                                       5'b10001,5'b10001,5'b01110};
                GLYPH_V: glyph_bits = {5'b10001,5'b10001,5'b10001,5'b10001,
                                       5'b10001,5'b01010,5'b00100};
                GLYPH_R: glyph_bits = {5'b11110,5'b10001,5'b10001,5'b11110,
                                       5'b10100,5'b10010,5'b10001};
                GLYPH_D: glyph_bits = {5'b11110,5'b10001,5'b10001,5'b10001,
                                       5'b10001,5'b10001,5'b11110};
                default: glyph_bits = {5'b10001,5'b10001,5'b01010,5'b00100,
                                       5'b00100,5'b00100,5'b00100};
            endcase
        end
    endfunction

    function glyph_at;
        input [9:0] x;
        input [9:0] y;
        input [9:0] base_x;
        input [9:0] base_y;
        input [3:0] glyph;
        reg [4:0] local_x;
        reg [4:0] local_y;
        reg [2:0] row;
        reg [2:0] col;
        reg [5:0] index;
        reg [34:0] bits;
        begin
            glyph_at = 1'b0;
            if ((x >= base_x) && (x < base_x + 10'd20) &&
                (y >= base_y) && (y < base_y + 10'd28)) begin
                local_x = x - base_x;
                local_y = y - base_y;
                row = local_y[4:2];
                col = local_x[4:2];
                index = (row << 2) + row + col;
                bits = glyph_bits(glyph);
                glyph_at = bits[34-index];
            end
        end
    endfunction

    function [7:0] heart_row;
        input [2:0] row;
        begin
            case (row)
                3'd0: heart_row = 8'b01100110;
                3'd1: heart_row = 8'b11111111;
                3'd2: heart_row = 8'b11111111;
                3'd3: heart_row = 8'b11111111;
                3'd4: heart_row = 8'b01111110;
                3'd5: heart_row = 8'b00111100;
                default: heart_row = 8'b00011000;
            endcase
        end
    endfunction

    function heart_at;
        input [9:0] x;
        input [9:0] y;
        input [9:0] base_x;
        input [9:0] base_y;
        reg [3:0] local_x;
        reg [3:0] local_y;
        reg [2:0] row;
        reg [2:0] col;
        reg [7:0] mask;
        begin
            heart_at = 1'b0;
            if ((x >= base_x) && (x < base_x + 10'd16) &&
                (y >= base_y) && (y < base_y + 10'd14)) begin
                local_x = x - base_x;
                local_y = y - base_y;
                row = local_y[3:1];
                col = local_x[3:1];
                mask = heart_row(row);
                heart_at = mask[7-col];
            end
        end
    endfunction

    function [6:0] building_height;
        input [3:0] tile;
        begin
            case (tile)
                4'd0, 4'd7: building_height = 7'd28;
                4'd1, 4'd9: building_height = 7'd54;
                4'd2, 4'd12: building_height = 7'd38;
                4'd3, 4'd14: building_height = 7'd68;
                4'd4, 4'd10: building_height = 7'd44;
                4'd5: building_height = 7'd76;
                default: building_height = 7'd34;
            endcase
        end
    endfunction

    wire [10:0] player_right = {1'b0, PLAYER_X} + PLAYER_W;
    wire [10:0] player_bottom = {1'b0, player_y} + PLAYER_H;
    wire [10:0] pipe_right = {1'b0, obstacle_x} + PIPE_W;
    wire [9:0] gap_top = (gap_y > GAP_HALF) ? gap_y - GAP_HALF : 10'd0;
    wire [10:0] gap_bottom_sum = {1'b0, gap_y} + GAP_HALF;
    wire [9:0] gap_bottom = (gap_bottom_sum > GROUND_Y)
                          ? GROUND_Y : gap_bottom_sum[9:0];
    wire [9:0] cap_left = (obstacle_x > 10'd4)
                        ? obstacle_x - 10'd4 : 10'd0;
    wire [10:0] cap_right = pipe_right + 11'd4;

    wire player_area = active_video && game_enabled &&
                       (pixel_x >= PLAYER_X) &&
                       ({1'b0, pixel_x} < player_right) &&
                       (pixel_y >= player_y) &&
                       ({1'b0, pixel_y} < player_bottom);
    wire [4:0] player_local_x = pixel_x - PLAYER_X;
    wire [4:0] player_local_y = pixel_y - player_y;
    wire [3:0] bird_x = player_local_x[4:1];
    wire [3:0] bird_y = player_local_y[4:1];
    wire [1:0] bird_frame = (frame_sequence[4:3] == 2'd3)
                          ? 2'd1 : frame_sequence[4:3];
    wire [15:0] body_outer_mask = bird_body_outer(bird_y);
    wire [15:0] body_inner_mask = bird_body_inner(bird_y);
    wire [15:0] face_mask = bird_face(bird_y);
    wire [15:0] wing_outer_mask = bird_wing_outer(bird_frame, bird_y);
    wire [15:0] wing_inner_mask = bird_wing_inner(bird_frame, bird_y);
    wire bird_outer_on = player_area &&
                         (body_outer_mask[15-bird_x] ||
                          wing_outer_mask[15-bird_x]);
    wire bird_body_on = player_area && body_inner_mask[15-bird_x];
    wire bird_wing_on = player_area && wing_inner_mask[15-bird_x];
    wire bird_face_on = player_area && face_mask[15-bird_x];
    wire bird_eye_on = player_area && (bird_y == 4'd3) &&
                       (bird_x == 4'd11);
    wire bird_beak_on = player_area &&
                        ((bird_y == 4'd4) || (bird_y == 4'd5)) &&
                        (bird_x >= 4'd14);

    wire particle_on = active_video && game_enabled && !game_control[1] &&
        (((pixel_x >= PLAYER_X - 10'd16) &&
          (pixel_x < PLAYER_X - 10'd12) &&
          (pixel_y >= player_y + 10'd12) &&
          (pixel_y < player_y + 10'd16)) ||
         ((pixel_x >= PLAYER_X - 10'd30) &&
          (pixel_x < PLAYER_X - 10'd26) &&
          (pixel_y >= player_y + 10'd16 + {8'b0, frame_sequence[1:0]}) &&
          (pixel_y < player_y + 10'd20 + {8'b0, frame_sequence[1:0]})) ||
         ((pixel_x >= PLAYER_X - 10'd44) &&
          (pixel_x < PLAYER_X - 10'd40) &&
          (pixel_y >= player_y + 10'd20) &&
          (pixel_y < player_y + 10'd24)));

    wire body_pipe_on = active_video && game_enabled &&
                        (pixel_x >= obstacle_x) &&
                        ({1'b0, pixel_x} < pipe_right) &&
                        (pixel_y < GROUND_Y) &&
                        ((pixel_y < gap_top) || (pixel_y >= gap_bottom));
    wire upper_cap_on = active_video && game_enabled &&
                        (pixel_x >= cap_left) &&
                        ({1'b0, pixel_x} < cap_right) &&
                        (pixel_y < gap_top) &&
                        (pixel_y + 10'd12 >= gap_top);
    wire lower_cap_on = active_video && game_enabled &&
                        (pixel_x >= cap_left) &&
                        ({1'b0, pixel_x} < cap_right) &&
                        (pixel_y >= gap_bottom) &&
                        (pixel_y < gap_bottom + 10'd12);
    wire pipe_on = body_pipe_on || upper_cap_on || lower_cap_on;
    wire [6:0] pipe_local_x = pixel_x -
                              ((upper_cap_on || lower_cap_on)
                                ? cap_left : obstacle_x);
    wire pipe_edge = pipe_on &&
                     ((pipe_local_x < 7'd4) ||
                      (pipe_local_x >= ((upper_cap_on || lower_cap_on)
                                         ? 7'd60 : 7'd52)) ||
                      (upper_cap_on && (pixel_y + 10'd4 >= gap_top)) ||
                      (lower_cap_on && (pixel_y < gap_bottom + 10'd4)));
    wire pipe_highlight = pipe_on && (pipe_local_x >= 7'd10) &&
                          (pipe_local_x < 7'd16);
    wire pipe_texture = pipe_on && pipe_local_x[3] && pixel_y[4];

    wire [9:0] cloud_scroll_x = pixel_x + {4'b0, frame_sequence[8:3]};
    wire [7:0] cloud_phase = cloud_scroll_x[7:0];
    wire cloud_a = active_video &&
        (((cloud_phase >= 8'd34) && (cloud_phase < 8'd118) &&
          (pixel_y >= 10'd92) && (pixel_y < 10'd108)) ||
         ((cloud_phase >= 8'd52) && (cloud_phase < 8'd100) &&
          (pixel_y >= 10'd76) && (pixel_y < 10'd108)) ||
         ((cloud_phase >= 8'd66) && (cloud_phase < 8'd88) &&
          (pixel_y >= 10'd64) && (pixel_y < 10'd108)));
    wire cloud_b = active_video &&
        (((cloud_phase >= 8'd164) && (cloud_phase < 8'd232) &&
          (pixel_y >= 10'd158) && (pixel_y < 10'd172)) ||
         ((cloud_phase >= 8'd180) && (cloud_phase < 8'd218) &&
          (pixel_y >= 10'd142) && (pixel_y < 10'd172)));
    wire cloud_on = cloud_a || cloud_b;
    wire cloud_shadow = cloud_on && pixel_y[3:2] == 2'b11;

    wire [9:0] city_scroll_x = pixel_x + {3'b0, frame_sequence[9:3]};
    wire [3:0] city_tile = city_scroll_x[8:5];
    wire [6:0] city_height = building_height(city_tile);
    wire city_on = active_video && (pixel_y < GROUND_Y) &&
                   ({1'b0, pixel_y} + city_height >= 11'd410) &&
                   (pixel_y >= 10'd330) && city_scroll_x[4:1] != 4'hf;
    wire city_window = city_on && city_scroll_x[3:2] == 2'b01 &&
                       pixel_y[3:2] == 2'b01;

    wire [7:0] far_hill_x = pixel_x[7:0] + frame_sequence[9:4];
    wire [6:0] far_triangle = far_hill_x[7]
                            ? (7'd127 - far_hill_x[6:0])
                            : far_hill_x[6:0];
    wire [9:0] far_hill_top = 10'd370 - {4'b0, far_triangle[6:1]};
    wire far_hill_on = active_video && (pixel_y >= far_hill_top) &&
                       (pixel_y < GROUND_Y);

    wire [7:0] near_hill_x = pixel_x[7:0] + {1'b0, frame_sequence[8:2]};
    wire [6:0] near_triangle = near_hill_x[7]
                             ? (7'd127 - near_hill_x[6:0])
                             : near_hill_x[6:0];
    wire [9:0] near_hill_top = 10'd420 - {4'b0, near_triangle[6:1]};
    wire near_hill_on = active_video && (pixel_y >= near_hill_top) &&
                        (pixel_y < GROUND_Y);

    wire [9:0] ground_scroll_x = pixel_x + frame_sequence[9:0];
    wire grass_on = active_video && (pixel_y >= GROUND_Y) &&
                    (pixel_y < 10'd456);
    wire grass_tip = grass_on &&
                     (pixel_y < GROUND_Y + 10'd5 +
                      {8'b0, ground_scroll_x[2:1]});
    wire stone_on = active_video && (pixel_y >= 10'd456);
    wire stone_mortar = stone_on &&
        ((pixel_y[4:0] < 5'd3) ||
         (((ground_scroll_x[5:0] + (pixel_y[5] ? 6'd24 : 6'd0)) & 6'h3f)
          < 6'd3));
    wire stone_highlight = stone_on && !stone_mortar &&
                           (pixel_y[4:0] < 5'd8);

    wire [4:0] mic_segments = (mic_level >= 16'd20)
                            ? 5'd10 : {1'b0, mic_level[4:1]};
    wire mic_icon_on = active_video &&
        ((((pixel_x >= 10'd18) && (pixel_x < 10'd28)) &&
          ((pixel_y >= 10'd18) && (pixel_y < 10'd34))) ||
         (((pixel_x >= 10'd14) && (pixel_x < 10'd32)) &&
          ((pixel_y >= 10'd30) && (pixel_y < 10'd34))) ||
         (((pixel_x >= 10'd22) && (pixel_x < 10'd26)) &&
          ((pixel_y >= 10'd34) && (pixel_y < 10'd40))) ||
         (((pixel_x >= 10'd16) && (pixel_x < 10'd32)) &&
          ((pixel_y >= 10'd38) && (pixel_y < 10'd42))));
    wire mic_status_on = active_video &&
                         (pixel_x >= 10'd38) && (pixel_x < 10'd50) &&
                         (pixel_y >= 10'd22) && (pixel_y < 10'd34);
    wire mic_bar_area = active_video &&
                        (pixel_x >= 10'd56) && (pixel_x < 10'd156) &&
                        (pixel_y >= 10'd22) && (pixel_y < 10'd34);
    wire mic_bar_lit = mic_bar_area &&
        (((mic_segments > 5'd0) && (pixel_x >= 10'd56) && (pixel_x < 10'd64)) ||
         ((mic_segments > 5'd1) && (pixel_x >= 10'd66) && (pixel_x < 10'd74)) ||
         ((mic_segments > 5'd2) && (pixel_x >= 10'd76) && (pixel_x < 10'd84)) ||
         ((mic_segments > 5'd3) && (pixel_x >= 10'd86) && (pixel_x < 10'd94)) ||
         ((mic_segments > 5'd4) && (pixel_x >= 10'd96) && (pixel_x < 10'd104)) ||
         ((mic_segments > 5'd5) && (pixel_x >= 10'd106) && (pixel_x < 10'd114)) ||
         ((mic_segments > 5'd6) && (pixel_x >= 10'd116) && (pixel_x < 10'd124)) ||
         ((mic_segments > 5'd7) && (pixel_x >= 10'd126) && (pixel_x < 10'd134)) ||
         ((mic_segments > 5'd8) && (pixel_x >= 10'd136) && (pixel_x < 10'd144)) ||
         ((mic_segments > 5'd9) && (pixel_x >= 10'd146) && (pixel_x < 10'd154)));

    wire score_hi_area = active_video &&
                         (pixel_x >= 10'd299) && (pixel_x < 10'd316) &&
                         (pixel_y >= 10'd18) && (pixel_y < 10'd45);
    wire score_lo_area = active_video &&
                         (pixel_x >= 10'd324) && (pixel_x < 10'd341) &&
                         (pixel_y >= 10'd18) && (pixel_y < 10'd45);
    wire score_hi_on = score_hi_area &&
        seven_pixel(score[7:4], pixel_x - 10'd299, pixel_y - 10'd18);
    wire score_lo_on = score_lo_area &&
        seven_pixel(score[3:0], pixel_x - 10'd324, pixel_y - 10'd18);
    wire score_shadow_on = active_video &&
        (((pixel_x >= 10'd301) && (pixel_x < 10'd318) &&
          (pixel_y >= 10'd20) && (pixel_y < 10'd47) &&
          seven_pixel(score[7:4], pixel_x - 10'd301, pixel_y - 10'd20)) ||
         ((pixel_x >= 10'd326) && (pixel_x < 10'd343) &&
          (pixel_y >= 10'd20) && (pixel_y < 10'd47) &&
          seven_pixel(score[3:0], pixel_x - 10'd326, pixel_y - 10'd20)));

    wire heart0 = heart_at(pixel_x, pixel_y, 10'd558, 10'd20);
    wire heart1 = heart_at(pixel_x, pixel_y, 10'd580, 10'd20);
    wire heart2 = heart_at(pixel_x, pixel_y, 10'd602, 10'd20);
    wire heart_any = heart0 || heart1 || heart2;
    wire heart_lit = (heart0 && (lives >= 2'd1)) ||
                     (heart1 && (lives >= 2'd2)) ||
                     (heart2 && (lives >= 2'd3));

    wire overlay_panel = active_video && game_control[1] &&
                         (pixel_x >= 10'd188) && (pixel_x < 10'd452) &&
                         (pixel_y >= 10'd190) && (pixel_y < 10'd264);
    wire overlay_border = overlay_panel &&
                          ((pixel_x < 10'd194) || (pixel_x >= 10'd446) ||
                           (pixel_y < 10'd196) || (pixel_y >= 10'd258));
    wire ready_text = waiting &&
        (glyph_at(pixel_x,pixel_y,10'd260,10'd213,GLYPH_R) ||
         glyph_at(pixel_x,pixel_y,10'd284,10'd213,GLYPH_E) ||
         glyph_at(pixel_x,pixel_y,10'd308,10'd213,GLYPH_A) ||
         glyph_at(pixel_x,pixel_y,10'd332,10'd213,GLYPH_D) ||
         glyph_at(pixel_x,pixel_y,10'd356,10'd213,GLYPH_Y));
    wire game_over_text = game_over &&
        (glyph_at(pixel_x,pixel_y,10'd224,10'd213,GLYPH_G) ||
         glyph_at(pixel_x,pixel_y,10'd248,10'd213,GLYPH_A) ||
         glyph_at(pixel_x,pixel_y,10'd272,10'd213,GLYPH_M) ||
         glyph_at(pixel_x,pixel_y,10'd296,10'd213,GLYPH_E) ||
         glyph_at(pixel_x,pixel_y,10'd320,10'd213,GLYPH_O) ||
         glyph_at(pixel_x,pixel_y,10'd344,10'd213,GLYPH_V) ||
         glyph_at(pixel_x,pixel_y,10'd368,10'd213,GLYPH_E) ||
         glyph_at(pixel_x,pixel_y,10'd392,10'd213,GLYPH_R));

    reg [11:0] rgb;
    always @(*) begin
        if (rst || !active_video)
            rgb = 12'h000;
        else if (ready_text || game_over_text)
            rgb = 12'hfff;
        else if (overlay_border)
            rgb = game_over ? 12'hf54 : 12'hfd2;
        else if (overlay_panel)
            rgb = 12'h124;
        else if (score_hi_on || score_lo_on)
            rgb = 12'hfff;
        else if (score_shadow_on)
            rgb = 12'h124;
        else if (heart_lit)
            rgb = player_hurt && frame_sequence[2] ? 12'hfff : 12'hf45;
        else if (heart_any)
            rgb = 12'h345;
        else if (mic_icon_on)
            rgb = 12'hfff;
        else if (mic_status_on)
            rgb = mic_calibrated ? 12'h2f4 : 12'hf92;
        else if (mic_bar_lit)
            rgb = mic_event_pending ? 12'hfd2 : 12'h2f4;
        else if (mic_bar_area)
            rgb = 12'h246;
        else if (bird_eye_on)
            rgb = 12'h013;
        else if (bird_face_on)
            rgb = 12'hfff;
        else if (bird_beak_on || bird_wing_on)
            rgb = player_hurt && frame_sequence[2] ? 12'hfff : 12'hf75;
        else if (bird_body_on)
            rgb = player_hurt && frame_sequence[2] ? 12'hfff : 12'hfd2;
        else if (bird_outer_on)
            rgb = 12'h123;
        else if (particle_on)
            rgb = 12'hfd2;
        else if (pipe_edge)
            rgb = 12'h064;
        else if (pipe_highlight)
            rgb = 12'haf4;
        else if (pipe_texture)
            rgb = 12'h197;
        else if (pipe_on)
            rgb = 12'h5c2;
        else if (grass_tip)
            rgb = 12'hbf3;
        else if (grass_on)
            rgb = ground_scroll_x[3] ? 12'h5a2 : 12'h7c2;
        else if (stone_mortar)
            rgb = 12'h246;
        else if (stone_highlight)
            rgb = 12'h8ac;
        else if (stone_on)
            rgb = ground_scroll_x[5] ? 12'h579 : 12'h68a;
        else if (near_hill_on)
            rgb = 12'h087;
        else if (city_window)
            rgb = 12'h8df;
        else if (city_on)
            rgb = 12'h28b;
        else if (far_hill_on)
            rgb = 12'h19a;
        else if (cloud_shadow)
            rgb = 12'hbef;
        else if (cloud_on)
            rgb = 12'hfff;
        else
            rgb = 12'h2bd;
    end

    always @(*) begin
        vga_r = rgb[11:8];
        vga_g = rgb[7:4];
        vga_b = rgb[3:0];
    end
endmodule

`default_nettype wire
