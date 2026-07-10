`timescale 1ns / 1ps
`default_nettype none

module ps2_keyboard(
    input  wire       clk,
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg  [7:0] scan_code,
    output reg        scan_valid
);
    reg [7:0] ps2_clk_filter;
    reg [7:0] ps2_data_filter;
    reg       ps2_clk_stable;
    reg       ps2_data_stable;
    reg       ps2_clk_stable_d;

    reg [3:0]  bit_count;
    reg [10:0] frame_shift;

    wire ps2_clk_fall = ps2_clk_stable_d && !ps2_clk_stable;
    wire odd_parity_ok = ^{frame_shift[8:1], frame_shift[9]};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps2_clk_filter <= 8'hff;
            ps2_data_filter <= 8'hff;
            ps2_clk_stable <= 1'b1;
            ps2_data_stable <= 1'b1;
            ps2_clk_stable_d <= 1'b1;
            bit_count <= 4'd0;
            frame_shift <= 11'b0;
            scan_code <= 8'b0;
            scan_valid <= 1'b0;
        end else begin
            scan_valid <= 1'b0;

            ps2_clk_filter <= {ps2_clk_filter[6:0], ps2_clk};
            ps2_data_filter <= {ps2_data_filter[6:0], ps2_data};

            if (&ps2_clk_filter)
                ps2_clk_stable <= 1'b1;
            else if (~|ps2_clk_filter)
                ps2_clk_stable <= 1'b0;

            if (&ps2_data_filter)
                ps2_data_stable <= 1'b1;
            else if (~|ps2_data_filter)
                ps2_data_stable <= 1'b0;

            ps2_clk_stable_d <= ps2_clk_stable;

            if (ps2_clk_fall) begin
                if (bit_count == 4'd0) begin
                    if (!ps2_data_stable) begin
                        frame_shift[0] <= 1'b0;
                        bit_count <= 4'd1;
                    end
                end else begin
                    frame_shift[bit_count] <= ps2_data_stable;

                    if (bit_count == 4'd10) begin
                        if (!frame_shift[0] && ps2_data_stable && odd_parity_ok) begin
                            scan_code <= frame_shift[8:1];
                            scan_valid <= 1'b1;
                        end

                        bit_count <= 4'd0;
                        frame_shift <= 11'b0;
                    end else begin
                        bit_count <= bit_count + 4'd1;
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
