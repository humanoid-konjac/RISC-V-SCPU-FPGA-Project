`timescale 1ns / 1ps
`default_nettype none

module mic_voice_trigger #(
    parameter integer DC_SHIFT          = 8,
    parameter integer ENVELOPE_SHIFT    = 7,
    parameter integer NORMAL_GAIN_SHIFT = 2,
    parameter integer VOICE_GAIN_SHIFT  = 3,
    parameter integer WARMUP_SAMPLES    = 2048,
    parameter integer CALIBRATION_SHIFT = 13,
    parameter integer COOLDOWN_SAMPLES  = 1953,
    parameter integer AUTO_HIGH_MARGIN  = 3,
    parameter integer VOICE_HIGH_MARGIN = 2,
    parameter integer AUTO_LOW_MARGIN   = 1,
    parameter integer CONFIRM_SAMPLES   = 64,
    parameter integer REARM_SAMPLES     = 586
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               enable,
    input  wire               calibrate_start,
    input  wire               event_clear,
    input  wire               manual_trigger,
    input  wire               sensitive_mode,
    input  wire               manual_threshold_enable,
    input  wire        [15:0] threshold_high_config,
    input  wire        [15:0] threshold_low_config,
    input  wire signed [15:0] pcm_sample,
    input  wire               sample_valid,
    output reg         [15:0] level,
    output reg         [15:0] noise_floor,
    output wire        [15:0] threshold_high_effective,
    output wire        [15:0] threshold_low_effective,
    output reg                calibrated,
    output reg                above_threshold,
    output reg                event_pulse,
    output reg                event_pending,
    output reg         [15:0] event_sequence
);
    localparam integer CALIBRATION_SAMPLES = (1 << CALIBRATION_SHIFT);

    reg signed [23:0] dc_q8;
    reg signed [23:0] envelope_q8;
    reg        [31:0] warmup_count;
    reg        [31:0] calibration_count;
    reg        [31:0] calibration_sum;
    reg        [31:0] cooldown_count;
    reg        [31:0] confirm_count;
    reg        [31:0] rearm_count;
    reg               sensitive_mode_d;

    wire signed [23:0] sample_extended =
        {{8{pcm_sample[15]}}, pcm_sample};
    wire signed [23:0] sample_q8 = sample_extended <<< 8;
    wire signed [23:0] dc_error_q8 = sample_q8 - dc_q8;
    wire signed [23:0] centered_q8 = sample_q8 - dc_q8;
    wire signed [23:0] normal_centered_q8 =
        centered_q8 <<< NORMAL_GAIN_SHIFT;
    wire signed [23:0] voice_centered_q8 =
        centered_q8 <<< VOICE_GAIN_SHIFT;
    wire signed [23:0] gained_centered_q8 = sensitive_mode
                                                ? voice_centered_q8
                                                : normal_centered_q8;
    wire        [23:0] magnitude_q8 = gained_centered_q8[23]
                                       ? (~gained_centered_q8 + 24'd1)
                                       : gained_centered_q8;
    wire signed [23:0] magnitude_signed_q8 =
        $signed({1'b0, magnitude_q8[22:0]});
    wire signed [23:0] envelope_error_q8 =
        magnitude_signed_q8 - envelope_q8;
    wire signed [23:0] dc_next_q8 =
        dc_q8 + (dc_error_q8 >>> DC_SHIFT);
    wire signed [23:0] envelope_next_q8 =
        envelope_q8 + (envelope_error_q8 >>> ENVELOPE_SHIFT);
    wire [15:0] level_next = envelope_next_q8[23]
                           ? 16'b0 : envelope_next_q8[23:8];

    wire [16:0] auto_high_sum =
        {1'b0, noise_floor} + (sensitive_mode
                                ? VOICE_HIGH_MARGIN : AUTO_HIGH_MARGIN);
    wire [16:0] auto_low_sum =
        {1'b0, noise_floor} + AUTO_LOW_MARGIN;
    wire [15:0] auto_high = auto_high_sum[16]
                          ? 16'hffff : auto_high_sum[15:0];
    wire [15:0] auto_low = auto_low_sum[16]
                         ? 16'hffff : auto_low_sum[15:0];
    wire [15:0] manual_low_safe =
        (threshold_low_config < threshold_high_config)
            ? threshold_low_config
            : ((threshold_high_config == 16'b0)
                ? 16'b0 : threshold_high_config - 16'd1);

    assign threshold_high_effective = manual_threshold_enable
                                    ? threshold_high_config : auto_high;
    assign threshold_low_effective = manual_threshold_enable
                                   ? manual_low_safe : auto_low;

    wire sensitivity_changed = sensitive_mode != sensitive_mode_d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dc_q8 <= 24'sd0;
            envelope_q8 <= 24'sd0;
            level <= 16'b0;
            noise_floor <= 16'b0;
            warmup_count <= 32'b0;
            calibration_count <= 32'b0;
            calibration_sum <= 32'b0;
            cooldown_count <= 32'b0;
            confirm_count <= 32'b0;
            rearm_count <= 32'b0;
            sensitive_mode_d <= sensitive_mode;
            calibrated <= 1'b0;
            above_threshold <= 1'b0;
            event_pulse <= 1'b0;
            event_pending <= 1'b0;
            event_sequence <= 16'b0;
        end else begin
            event_pulse <= 1'b0;
            sensitive_mode_d <= sensitive_mode;

            if (event_clear)
                event_pending <= 1'b0;

            if (calibrate_start || sensitivity_changed) begin
                dc_q8 <= 24'sd0;
                envelope_q8 <= 24'sd0;
                level <= 16'b0;
                noise_floor <= 16'b0;
                warmup_count <= 32'b0;
                calibration_count <= 32'b0;
                calibration_sum <= 32'b0;
                cooldown_count <= 32'b0;
                confirm_count <= 32'b0;
                rearm_count <= 32'b0;
                calibrated <= 1'b0;
                above_threshold <= 1'b0;
                event_pending <= 1'b0;
            end else if (!enable) begin
                above_threshold <= 1'b0;
                cooldown_count <= 32'b0;
                confirm_count <= 32'b0;
                rearm_count <= 32'b0;
            end else if (sample_valid) begin
                dc_q8 <= dc_next_q8;
                envelope_q8 <= envelope_next_q8;
                level <= level_next;

                if (!calibrated) begin
                    above_threshold <= 1'b0;
                    cooldown_count <= 32'b0;
                    confirm_count <= 32'b0;
                    rearm_count <= 32'b0;

                    if (warmup_count < WARMUP_SAMPLES) begin
                        warmup_count <= warmup_count + 32'd1;
                    end else if (calibration_count == CALIBRATION_SAMPLES - 1) begin
                        noise_floor <=
                            (calibration_sum + level_next) >> CALIBRATION_SHIFT;
                        calibrated <= 1'b1;
                        calibration_count <= 32'b0;
                        calibration_sum <= 32'b0;
                    end else begin
                        calibration_count <= calibration_count + 32'd1;
                        calibration_sum <= calibration_sum + level_next;
                    end
                end else begin
                    if (cooldown_count != 0)
                        cooldown_count <= cooldown_count - 32'd1;

                    if (above_threshold) begin
                        confirm_count <= 32'b0;
                        if (level_next <= threshold_low_effective) begin
                            if ((REARM_SAMPLES <= 1) ||
                                (rearm_count >= REARM_SAMPLES - 1)) begin
                                above_threshold <= 1'b0;
                                rearm_count <= 32'b0;
                            end else begin
                                rearm_count <= rearm_count + 32'd1;
                            end
                        end else begin
                            rearm_count <= 32'b0;
                        end
                    end else begin
                        rearm_count <= 32'b0;
                        if (!manual_trigger && (cooldown_count == 0) &&
                            (level_next >= threshold_high_effective)) begin
                            if ((CONFIRM_SAMPLES <= 1) ||
                                (confirm_count >= CONFIRM_SAMPLES - 1)) begin
                                above_threshold <= 1'b1;
                                event_pulse <= 1'b1;
                                event_pending <= 1'b1;
                                event_sequence <= event_sequence + 16'd1;
                                cooldown_count <= COOLDOWN_SAMPLES;
                                confirm_count <= 32'b0;
                            end else begin
                                confirm_count <= confirm_count + 32'd1;
                            end
                        end else begin
                            confirm_count <= 32'b0;
                        end
                    end
                end
            end

            // Manual board-test inputs are deliberately accepted before
            // microphone calibration.
            if (enable && manual_trigger) begin
                event_pulse <= 1'b1;
                event_pending <= 1'b1;
                event_sequence <= event_sequence + 16'd1;
                cooldown_count <= COOLDOWN_SAMPLES;
                confirm_count <= 32'b0;
            end
        end
    end
endmodule

`default_nettype wire
