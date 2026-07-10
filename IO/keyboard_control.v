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
    output reg        move_right,
    output reg        jump
);
    reg break_pending;
    reg extended_pending;
    reg w_held;
    reg space_held;
    reg arrow_up_held;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            w_held <= 1'b0;
            space_held <= 1'b0;
            arrow_up_held <= 1'b0;
            move_up <= 1'b0;
            move_down <= 1'b0;
            move_left <= 1'b0;
            move_right <= 1'b0;
            jump <= 1'b0;
        end else begin
            move_up <= 1'b0;
            move_down <= 1'b0;
            move_left <= 1'b0;
            move_right <= 1'b0;
            jump <= 1'b0;

            if (scan_valid) begin
                if (scan_code == 8'he0) begin
                    extended_pending <= 1'b1;
                end else if (scan_code == 8'hf0) begin
                    break_pending <= 1'b1;
                end else if (break_pending) begin
                    if (extended_pending) begin
                        case (scan_code)
                            8'h75: arrow_up_held <= 1'b0;
                            default: ;
                        endcase
                    end else begin
                        case (scan_code)
                            8'h1d: w_held <= 1'b0;
                            8'h29: space_held <= 1'b0;
                            default: ;
                        endcase
                    end
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end else begin
                    if (extended_pending) begin
                        case (scan_code)
                            8'h75: begin
                                move_up <= 1'b1;
                                jump <= !arrow_up_held;
                                arrow_up_held <= 1'b1;
                            end
                            8'h72: move_down <= 1'b1;
                            8'h6b: move_left <= 1'b1;
                            8'h74: move_right <= 1'b1;
                            default: ;
                        endcase
                    end else begin
                        case (scan_code)
                            8'h1d: begin
                                move_up <= 1'b1;
                                jump <= !w_held;
                                w_held <= 1'b1;
                            end
                            8'h1b: move_down <= 1'b1;
                            8'h1c: move_left <= 1'b1;
                            8'h23: move_right <= 1'b1;
                            8'h29: begin
                                jump <= !space_held;
                                space_held <= 1'b1;
                            end
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
