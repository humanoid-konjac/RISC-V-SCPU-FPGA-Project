`timescale 1ns/1ps

module vga_game_renderer_tb;
    reg rst;
    reg active_video;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg [1:0] game_control;
    reg [9:0] player_y;
    reg [9:0] obstacle_x;
    reg [9:0] gap_y;
    reg [15:0] score;
    reg [1:0] lives;
    reg player_hurt;
    reg [31:0] frame_sequence;
    reg [15:0] mic_level;
    reg mic_calibrated;
    reg mic_event_pending;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    integer errors;

    vga_game_renderer dut (
        .rst(rst), .active_video(active_video),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .game_control(game_control), .player_y(player_y),
        .obstacle_x(obstacle_x), .gap_y(gap_y), .score(score),
        .lives(lives), .player_hurt(player_hurt),
        .frame_sequence(frame_sequence),
        .mic_level(mic_level), .mic_calibrated(mic_calibrated),
        .mic_event_pending(mic_event_pending),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    task check_rgb;
        input [127:0] name;
        input [11:0] expected;
        begin
            #1;
            if ({vga_r, vga_g, vga_b} !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s got=%03h expected=%03h", name,
                         {vga_r, vga_g, vga_b}, expected);
            end
        end
    endtask

    initial begin
        rst = 1'b0;
        active_video = 1'b1;
        game_control = 2'b01;
        player_y = 10'd224;
        obstacle_x = 10'd400;
        gap_y = 10'd240;
        score = 16'h0001;
        lives = 2'd3;
        player_hurt = 1'b0;
        frame_sequence = 32'd0;
        mic_level = 16'd0;
        mic_calibrated = 1'b1;
        mic_event_pending = 1'b0;
        errors = 0;

        pixel_x = 10'd200;
        pixel_y = 10'd100;
        check_rgb("sky", 12'h2bd);

        pixel_x = 10'd150;
        pixel_y = 10'd230;
        check_rgb("player", 12'hf75);

        pixel_x = 10'd410;
        pixel_y = 10'd100;
        check_rgb("pipe", 12'haf4);

        pixel_x = 10'd410;
        pixel_y = 10'd220;
        check_rgb("wide pipe gap", 12'h2bd);

        pixel_x = 10'd560;
        pixel_y = 10'd22;
        check_rgb("life heart", 12'hf45);

        pixel_x = 10'd58;
        pixel_y = 10'd24;
        mic_level = 16'd14;
        check_rgb("microphone meter", 12'h2f4);

        game_control = 2'b11;
        lives = 2'd0;
        pixel_x = 10'd190;
        pixel_y = 10'd192;
        check_rgb("game-over frame", 12'hf54);

        active_video = 1'b0;
        check_rgb("blanking", 12'h000);

        if (errors == 0)
            $display("PASS: VGA game renderer test completed");
        else
            $display("FAIL: VGA game renderer test completed with %0d errors", errors);
        $finish;
    end
endmodule
