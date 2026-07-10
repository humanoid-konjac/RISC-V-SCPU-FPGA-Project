`timescale 1ns / 1ps
`default_nettype none

module mic_pdm_rx #(
    parameter integer PDM_HALF_DIV = 20,
    parameter integer DECIMATION  = 128
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               mic_data,
    output reg                mic_clk,
    output wire               mic_lrsel,
    output reg signed [15:0]  pcm_sample,
    output reg        [15:0]  density,
    output reg                sample_valid
);
    reg [15:0] half_div_count;
    reg [15:0] sample_count;
    reg [15:0] ones_count;

    (* ASYNC_REG = "TRUE" *) reg mic_data_meta;
    (* ASYNC_REG = "TRUE" *) reg mic_data_sync;

    wire [16:0] ones_with_current =
        {1'b0, ones_count} + (mic_data_sync ? 17'd1 : 17'd0);

    localparam integer PCM_CENTER = DECIMATION / 2;

    assign mic_lrsel = 1'b0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mic_data_meta <= 1'b0;
            mic_data_sync <= 1'b0;
        end else begin
            mic_data_meta <= mic_data;
            mic_data_sync <= mic_data_meta;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            half_div_count <= 16'b0;
            sample_count <= 16'b0;
            ones_count <= 16'b0;
            mic_clk <= 1'b0;
            pcm_sample <= 16'sd0;
            density <= 16'b0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            if (half_div_count == PDM_HALF_DIV - 1) begin
                half_div_count <= 16'b0;
                mic_clk <= ~mic_clk;

                // mic_lrsel=0: data is stable for the rising mic clock edge.
                // All processing remains in the 100 MHz clock domain.
                if (!mic_clk) begin
                    if (sample_count == DECIMATION - 1) begin
                        density <= ones_with_current[15:0];
                        pcm_sample <= $signed(ones_with_current) - PCM_CENTER;
                        sample_count <= 16'b0;
                        ones_count <= 16'b0;
                        sample_valid <= 1'b1;
                    end else begin
                        sample_count <= sample_count + 16'd1;
                        if (mic_data_sync)
                            ones_count <= ones_count + 16'd1;
                    end
                end
            end else begin
                half_div_count <= half_div_count + 16'd1;
            end
        end
    end
endmodule

`default_nettype wire
