`timescale 1ns/1ps

module mic_voice_trigger_tb;
    reg clk;
    reg rst;
    reg enable;
    reg calibrate_start;
    reg event_clear;
    reg manual_trigger;
    reg sensitive_mode;
    reg manual_threshold_enable;
    reg [15:0] threshold_high_config;
    reg [15:0] threshold_low_config;
    reg signed [15:0] pcm_sample;
    reg sample_valid;
    wire [15:0] level;
    wire [15:0] noise_floor;
    wire [15:0] threshold_high_effective;
    wire [15:0] threshold_low_effective;
    wire calibrated;
    wire above_threshold;
    wire event_pulse;
    wire event_pending;
    wire [15:0] event_sequence;
    integer errors;
    integer i;

    mic_voice_trigger #(
        .DC_SHIFT(4),
        .ENVELOPE_SHIFT(1),
        .NORMAL_GAIN_SHIFT(1),
        .VOICE_GAIN_SHIFT(3),
        .WARMUP_SAMPLES(2),
        .CALIBRATION_SHIFT(2),
        .COOLDOWN_SAMPLES(4),
        .AUTO_HIGH_MARGIN(3),
        .VOICE_HIGH_MARGIN(2),
        .AUTO_LOW_MARGIN(1),
        .CONFIRM_SAMPLES(2),
        .REARM_SAMPLES(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .calibrate_start(calibrate_start),
        .event_clear(event_clear),
        .manual_trigger(manual_trigger),
        .sensitive_mode(sensitive_mode),
        .manual_threshold_enable(manual_threshold_enable),
        .threshold_high_config(threshold_high_config),
        .threshold_low_config(threshold_low_config),
        .pcm_sample(pcm_sample),
        .sample_valid(sample_valid),
        .level(level),
        .noise_floor(noise_floor),
        .threshold_high_effective(threshold_high_effective),
        .threshold_low_effective(threshold_low_effective),
        .calibrated(calibrated),
        .above_threshold(above_threshold),
        .event_pulse(event_pulse),
        .event_pending(event_pending),
        .event_sequence(event_sequence)
    );

    always #5 clk = ~clk;

    task push_sample;
        input signed [15:0] value;
        begin
            @(negedge clk);
            pcm_sample = value;
            sample_valid = 1'b1;
            @(negedge clk);
            sample_valid = 1'b0;
        end
    endtask

    task pulse_clear;
        begin
            @(negedge clk);
            event_clear = 1'b1;
            @(negedge clk);
            event_clear = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        enable = 1'b1;
        calibrate_start = 1'b0;
        event_clear = 1'b0;
        manual_trigger = 1'b0;
        sensitive_mode = 1'b1;
        manual_threshold_enable = 1'b0;
        threshold_high_config = 16'd20;
        threshold_low_config = 16'd10;
        pcm_sample = 16'sd0;
        sample_valid = 1'b0;
        errors = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        for (i = 0; i < 7; i = i + 1)
            push_sample(16'sd0);

        if (!calibrated) begin
            errors = errors + 1;
            $display("FAIL: automatic calibration did not complete");
        end
        if (threshold_high_effective !== 16'd2) begin
            errors = errors + 1;
            $display("FAIL: voice threshold got=%0d expected=2",
                     threshold_high_effective);
        end

        for (i = 0; i < 4; i = i + 1) begin
            push_sample(16'sd2);
            push_sample(-16'sd2);
        end

        if (!event_pending || event_sequence != 16'd1) begin
            errors = errors + 1;
            $display("FAIL: voice burst did not create exactly one sticky event");
        end

        for (i = 0; i < 12; i = i + 1) begin
            push_sample(16'sd2);
            push_sample(-16'sd2);
        end
        if (event_sequence != 16'd1) begin
            errors = errors + 1;
            $display("FAIL: sustained sound retriggered without rearming");
        end

        pulse_clear();
        if (event_pending) begin
            errors = errors + 1;
            $display("FAIL: event clear did not clear the sticky event");
        end

        for (i = 0; i < 16; i = i + 1)
            push_sample(16'sd0);
        if (above_threshold) begin
            errors = errors + 1;
            $display("FAIL: quiet period did not rearm voice trigger");
        end

        for (i = 0; i < 4; i = i + 1) begin
            push_sample(16'sd2);
            push_sample(-16'sd2);
        end
        if (!event_pending || event_sequence != 16'd2) begin
            errors = errors + 1;
            $display("FAIL: second short sound did not retrigger after quiet");
        end

        pulse_clear();

        @(negedge clk);
        manual_trigger = 1'b1;
        @(negedge clk);
        manual_trigger = 1'b0;
        if (!event_pending || event_sequence != 16'd3) begin
            errors = errors + 1;
            $display("FAIL: manual board-test trigger failed");
        end

        if (errors == 0)
            $display("PASS: microphone voice trigger test completed");
        else
            $display("FAIL: microphone voice trigger test completed with %0d errors", errors);
        $finish;
    end
endmodule
