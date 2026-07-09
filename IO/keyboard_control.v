`timescale 1ns / 1ps
`default_nettype none

module keyboard_control(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] scan_code,
    input  wire       scan_valid,
    output reg        move_up,
    output reg        move_down,
    output reg        move_left,
    output reg        move_right
);
    reg break_pending;
    reg extended_pending;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            move_up <= 1'b0;
            move_down <= 1'b0;
            move_left <= 1'b0;
            move_right <= 1'b0;
        end else begin
            move_up <= 1'b0;
            move_down <= 1'b0;
            move_left <= 1'b0;
            move_right <= 1'b0;

            if (scan_valid) begin
                if (scan_code == 8'he0) begin
                    extended_pending <= 1'b1;
                end else if (scan_code == 8'hf0) begin
                    break_pending <= 1'b1;
                end else if (break_pending) begin
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end else begin
                    if (extended_pending) begin
                        case (scan_code)
                            8'h75: move_up <= 1'b1;
                            8'h72: move_down <= 1'b1;
                            8'h6b: move_left <= 1'b1;
                            8'h74: move_right <= 1'b1;
                            default: ;
                        endcase
                    end else begin
                        case (scan_code)
                            8'h1d: move_up <= 1'b1;    // W
                            8'h1b: move_down <= 1'b1;  // S
                            8'h1c: move_left <= 1'b1;  // A
                            8'h23: move_right <= 1'b1; // D
                            default: ;
                        endcase
                    end
                    extended_pending <= 1'b0;
                end
            end
        end
    end
endmodule

`default_nettype wire
