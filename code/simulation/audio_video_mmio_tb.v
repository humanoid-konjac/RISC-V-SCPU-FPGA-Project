`timescale 1ns/1ps

module audio_video_mmio_tb;
    reg clk;
    reg rst;
    reg mic_we;
    reg video_we;
    reg frame_tick;
    reg [3:0] address;
    reg [31:0] write_data;
    wire [31:0] mic_read_data;
    wire [31:0] video_read_data;
    wire mic_enable;
    wire manual_threshold_enable;
    wire [15:0] threshold_high_config;
    wire [15:0] threshold_low_config;
    wire calibrate_start;
    wire event_clear;
    wire [1:0] game_control;
    wire [9:0] player_y;
    wire [9:0] obstacle_x;
    wire [9:0] gap_y;
    wire [15:0] score;
    wire [1:0] lives;
    wire player_hurt;
    wire [31:0] frame_sequence;
    integer errors;

    mic_mmio mic (
        .clk(clk), .rst(rst), .write_enable(mic_we),
        .word_address(address), .write_data(write_data),
        .pcm_sample(-16'sd7), .level(16'd13), .noise_floor(16'd2),
        .threshold_high_effective(16'd10),
        .threshold_low_effective(16'd6),
        .calibrated(1'b1), .above_threshold(1'b0),
        .event_pending(1'b1), .event_sequence(16'd9),
        .read_data(mic_read_data), .enable(mic_enable),
        .manual_threshold_enable(manual_threshold_enable),
        .threshold_high_config(threshold_high_config),
        .threshold_low_config(threshold_low_config),
        .calibrate_start(calibrate_start), .event_clear(event_clear)
    );

    video_mmio video (
        .clk(clk), .rst(rst), .frame_tick(frame_tick),
        .write_enable(video_we), .word_address(address),
        .write_data(write_data), .read_data(video_read_data),
        .game_control(game_control), .player_y(player_y),
        .obstacle_x(obstacle_x), .gap_y(gap_y), .score(score),
        .lives(lives), .player_hurt(player_hurt),
        .frame_sequence(frame_sequence)
    );

    always #5 clk = ~clk;

    task write_mic;
        input [3:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            address = addr;
            write_data = data;
            mic_we = 1'b1;
            @(negedge clk);
            mic_we = 1'b0;
        end
    endtask

    task write_video;
        input [3:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            address = addr;
            write_data = data;
            video_we = 1'b1;
            @(negedge clk);
            video_we = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        mic_we = 1'b0;
        video_we = 1'b0;
        frame_tick = 1'b0;
        address = 4'b0;
        write_data = 32'b0;
        errors = 0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        write_mic(4'h4, {16'd5, 16'd12});
        if (threshold_high_config != 16'd12 || threshold_low_config != 16'd5) begin
            errors = errors + 1;
            $display("FAIL: microphone threshold write/readback");
        end

        write_mic(4'h0, 32'h0000_0007);
        if (!mic_enable || !manual_threshold_enable || !calibrate_start) begin
            errors = errors + 1;
            $display("FAIL: microphone control write");
        end
        @(posedge clk);
        #1;
        if (calibrate_start) begin
            errors = errors + 1;
            $display("FAIL: calibration command was not a one-cycle pulse");
        end

        write_mic(4'h1, 32'h0000_0002);
        if (!event_clear) begin
            errors = errors + 1;
            $display("FAIL: microphone event-clear write");
        end

        write_video(4'h1, 32'd123);
        write_video(4'h2, 32'd456);
        write_video(4'h3, 32'd200);
        write_video(4'h4, 32'd42);
        write_video(4'h6, 32'h0000_0102);
        if (player_y != 10'd123 || obstacle_x != 10'd456 ||
            gap_y != 10'd200 || score != 16'd42 || lives != 2'd2 ||
            !player_hurt) begin
            errors = errors + 1;
            $display("FAIL: video state register writes");
        end

        @(negedge clk);
        frame_tick = 1'b1;
        @(negedge clk);
        frame_tick = 1'b0;
        if (frame_sequence != 32'd1) begin
            errors = errors + 1;
            $display("FAIL: video frame sequence increment");
        end

        if (errors == 0)
            $display("PASS: audio/video MMIO test completed");
        else
            $display("FAIL: audio/video MMIO test completed with %0d errors", errors);
        $finish;
    end
endmodule
