`timescale 1ns/1ps

module vga_game_frame_tb;
    reg rst;
    reg active_video;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    integer output_file;
    integer x;
    integer y;

    vga_game_renderer renderer (
        .rst(rst),
        .active_video(active_video),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .game_control(2'b01),
        .player_y(10'd218),
        .obstacle_x(10'd404),
        .gap_y(10'd240),
        .score(16'h0008),
        .lives(2'd3),
        .player_hurt(1'b0),
        .frame_sequence(32'd16),
        .mic_level(16'd14),
        .mic_calibrated(1'b1),
        .mic_event_pending(1'b0),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );

    initial begin
        rst = 1'b0;
        active_video = 1'b1;
        pixel_x = 10'b0;
        pixel_y = 10'b0;
        output_file = $fopen("code/simulation/sim_out/game_preview.ppm", "wb");
        $fwrite(output_file, "P6\n640 480\n255\n");

        for (y = 0; y < 480; y = y + 1) begin
            for (x = 0; x < 640; x = x + 1) begin
                pixel_x = x[9:0];
                pixel_y = y[9:0];
                #1;
                $fwrite(output_file, "%c%c%c",
                        {vga_r, vga_r}, {vga_g, vga_g}, {vga_b, vga_b});
            end
        end

        $fclose(output_file);
        $display("PASS: rendered game_preview.ppm");
        $finish;
    end
endmodule
