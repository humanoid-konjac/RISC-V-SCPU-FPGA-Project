`timescale 1ns / 1ps
`default_nettype none

module mic_mmio(
    input  wire               clk,
    input  wire               rst,
    input  wire               write_enable,
    input  wire        [3:0]  word_address,
    input  wire        [31:0] write_data,
    input  wire signed [15:0] pcm_sample,
    input  wire        [15:0] level,
    input  wire        [15:0] noise_floor,
    input  wire        [15:0] threshold_high_effective,
    input  wire        [15:0] threshold_low_effective,
    input  wire               calibrated,
    input  wire               above_threshold,
    input  wire               event_pending,
    input  wire        [15:0] event_sequence,
    output reg         [31:0] read_data,
    output reg                enable,
    output reg                manual_threshold_enable,
    output reg         [15:0] threshold_high_config,
    output reg         [15:0] threshold_low_config,
    output reg                calibrate_start,
    output reg                event_clear
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enable <= 1'b1;
            manual_threshold_enable <= 1'b0;
            threshold_high_config <= 16'd16;
            threshold_low_config <= 16'd8;
            calibrate_start <= 1'b0;
            event_clear <= 1'b0;
        end else begin
            calibrate_start <= 1'b0;
            event_clear <= 1'b0;

            if (write_enable) begin
                case (word_address)
                    4'h0: begin
                        enable <= write_data[0];
                        manual_threshold_enable <= write_data[2];
                        calibrate_start <= write_data[1];
                    end
                    4'h1: event_clear <= write_data[1];
                    4'h4: begin
                        threshold_high_config <= write_data[15:0];
                        threshold_low_config <= write_data[31:16];
                    end
                    default: begin
                        enable <= enable;
                    end
                endcase
            end
        end
    end

    always @(*) begin
        case (word_address)
            4'h0: read_data = {29'b0, manual_threshold_enable, 1'b0, enable};
            4'h1: read_data = {28'b0, 1'b0, above_threshold,
                              event_pending, calibrated};
            4'h2: read_data = {16'b0, level};
            4'h3: read_data = {{16{pcm_sample[15]}}, pcm_sample};
            4'h4: read_data = {threshold_low_config, threshold_high_config};
            4'h5: read_data = {16'b0, noise_floor};
            4'h6: read_data = {16'b0, event_sequence};
            4'h7: read_data = {threshold_low_effective,
                              threshold_high_effective};
            default: read_data = 32'b0;
        endcase
    end
endmodule

`default_nettype wire
