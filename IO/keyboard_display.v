`timescale 1ns / 1ps
`default_nettype none

module keyboard_display(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] scan_code,
    input  wire       scan_valid,
    output reg [31:0] display_hex,
    output reg [7:0]  last_scan_code,
    output reg [7:0]  last_ascii_code,
    output reg        key_event
);
    reg break_pending;
    reg extended_pending;

    function [7:0] scan_to_ascii;
        input [7:0] code;
        input       extended;
        begin
            if (extended) begin
                case (code)
                    8'h75: scan_to_ascii = 8'h55; // Up -> U
                    8'h72: scan_to_ascii = 8'h44; // Down -> D
                    8'h6b: scan_to_ascii = 8'h4c; // Left -> L
                    8'h74: scan_to_ascii = 8'h52; // Right -> R
                    default: scan_to_ascii = 8'h00;
                endcase
            end else begin
                case (code)
                    8'h1c: scan_to_ascii = 8'h41; // A
                    8'h32: scan_to_ascii = 8'h42; // B
                    8'h21: scan_to_ascii = 8'h43; // C
                    8'h23: scan_to_ascii = 8'h44; // D
                    8'h24: scan_to_ascii = 8'h45; // E
                    8'h2b: scan_to_ascii = 8'h46; // F
                    8'h34: scan_to_ascii = 8'h47; // G
                    8'h33: scan_to_ascii = 8'h48; // H
                    8'h43: scan_to_ascii = 8'h49; // I
                    8'h3b: scan_to_ascii = 8'h4a; // J
                    8'h42: scan_to_ascii = 8'h4b; // K
                    8'h4b: scan_to_ascii = 8'h4c; // L
                    8'h3a: scan_to_ascii = 8'h4d; // M
                    8'h31: scan_to_ascii = 8'h4e; // N
                    8'h44: scan_to_ascii = 8'h4f; // O
                    8'h4d: scan_to_ascii = 8'h50; // P
                    8'h15: scan_to_ascii = 8'h51; // Q
                    8'h2d: scan_to_ascii = 8'h52; // R
                    8'h1b: scan_to_ascii = 8'h53; // S
                    8'h2c: scan_to_ascii = 8'h54; // T
                    8'h3c: scan_to_ascii = 8'h55; // U
                    8'h2a: scan_to_ascii = 8'h56; // V
                    8'h1d: scan_to_ascii = 8'h57; // W
                    8'h22: scan_to_ascii = 8'h58; // X
                    8'h35: scan_to_ascii = 8'h59; // Y
                    8'h1a: scan_to_ascii = 8'h5a; // Z

                    8'h45: scan_to_ascii = 8'h30; // 0
                    8'h16: scan_to_ascii = 8'h31; // 1
                    8'h1e: scan_to_ascii = 8'h32; // 2
                    8'h26: scan_to_ascii = 8'h33; // 3
                    8'h25: scan_to_ascii = 8'h34; // 4
                    8'h2e: scan_to_ascii = 8'h35; // 5
                    8'h36: scan_to_ascii = 8'h36; // 6
                    8'h3d: scan_to_ascii = 8'h37; // 7
                    8'h3e: scan_to_ascii = 8'h38; // 8
                    8'h46: scan_to_ascii = 8'h39; // 9

                    8'h29: scan_to_ascii = 8'h20; // Space
                    8'h5a: scan_to_ascii = 8'h0d; // Enter
                    8'h66: scan_to_ascii = 8'h08; // Backspace
                    8'h76: scan_to_ascii = 8'h1b; // Esc
                    8'h0d: scan_to_ascii = 8'h09; // Tab
                    8'h4e: scan_to_ascii = 8'h2d; // -
                    8'h55: scan_to_ascii = 8'h3d; // =
                    8'h54: scan_to_ascii = 8'h5b; // [
                    8'h5b: scan_to_ascii = 8'h5d; // ]
                    8'h4c: scan_to_ascii = 8'h3b; // ;
                    8'h52: scan_to_ascii = 8'h27; // '
                    8'h41: scan_to_ascii = 8'h2c; // ,
                    8'h49: scan_to_ascii = 8'h2e; // .
                    8'h4a: scan_to_ascii = 8'h2f; // /
                    8'h0e: scan_to_ascii = 8'h60; // `
                    8'h5d: scan_to_ascii = 8'h5c; // backslash
                    default: scan_to_ascii = 8'h00;
                endcase
            end
        end
    endfunction

    reg [7:0] ascii_next;

    always @(*) begin
        ascii_next = scan_to_ascii(scan_code, extended_pending);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            display_hex <= 32'b0;
            last_scan_code <= 8'b0;
            last_ascii_code <= 8'b0;
            key_event <= 1'b0;
        end else begin
            key_event <= 1'b0;

            if (scan_valid) begin
                if (scan_code == 8'he0) begin
                    extended_pending <= 1'b1;
                end else if (scan_code == 8'hf0) begin
                    break_pending <= 1'b1;
                end else if (break_pending) begin
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end else begin
                    last_scan_code <= scan_code;
                    last_ascii_code <= ascii_next;
                    display_hex <= {8'h00, ascii_next, 8'h00, scan_code};
                    key_event <= 1'b1;
                    extended_pending <= 1'b0;
                end
            end
        end
    end
endmodule

`default_nettype wire
