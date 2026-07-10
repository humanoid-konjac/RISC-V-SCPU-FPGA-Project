`timescale 1ns / 1ps
`default_nettype none

module video_mmio(
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire        write_enable,
    input  wire [3:0]  word_address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data,
    output reg  [1:0]  game_control,
    output reg  [9:0]  player_y,
    output reg  [9:0]  obstacle_x,
    output reg  [9:0]  gap_y,
    output reg  [15:0] score,
    output reg  [1:0]  lives,
    output reg         player_hurt,
    output reg  [31:0] frame_sequence
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            game_control <= 2'b11;
            player_y <= 10'd224;
            obstacle_x <= 10'd620;
            gap_y <= 10'd240;
            score <= 16'b0;
            lives <= 2'd3;
            player_hurt <= 1'b0;
            frame_sequence <= 32'b0;
        end else begin
            if (frame_tick)
                frame_sequence <= frame_sequence + 32'd1;

            if (write_enable) begin
                case (word_address)
                    4'h0: game_control <= write_data[1:0];
                    4'h1: player_y <= write_data[9:0];
                    4'h2: obstacle_x <= write_data[9:0];
                    4'h3: gap_y <= write_data[9:0];
                    4'h4: score <= write_data[15:0];
                    4'h6: begin
                        lives <= write_data[1:0];
                        player_hurt <= write_data[8];
                    end
                    default: begin
                        game_control <= game_control;
                    end
                endcase
            end
        end
    end

    always @(*) begin
        case (word_address)
            4'h0: read_data = {30'b0, game_control};
            4'h1: read_data = {22'b0, player_y};
            4'h2: read_data = {22'b0, obstacle_x};
            4'h3: read_data = {22'b0, gap_y};
            4'h4: read_data = {16'b0, score};
            4'h5: read_data = frame_sequence;
            4'h6: read_data = {23'b0, player_hurt, 6'b0, lives};
            default: read_data = 32'b0;
        endcase
    end
endmodule

`default_nettype wire
