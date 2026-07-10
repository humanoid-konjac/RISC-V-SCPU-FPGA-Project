`timescale 1ns / 1ps
`default_nettype none

module keyboard_event_mmio(
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  scan_code,
    input  wire        scan_valid,
    input  wire        write_en,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data,
    output reg         key_ready,
    output reg  [7:0]  key_code
);
    localparam [7:0] KEY_NONE    = 8'd0;
    localparam [7:0] KEY_LEFT    = 8'd1;
    localparam [7:0] KEY_RIGHT   = 8'd2;
    localparam [7:0] KEY_CONFIRM = 8'd3;
    localparam [7:0] KEY_CANCEL  = 8'd4;
    localparam [7:0] KEY_RESTART = 8'd5;

    localparam [11:0] ADDR_STATUS = 12'h000;
    localparam [11:0] ADDR_CODE   = 12'h004;
    localparam [11:0] ADDR_ACK    = 12'h008;

    reg break_pending;
    reg extended_pending;
    reg [7:0] decoded_code;

    wire ack_write = write_en && (addr[11:0] == ADDR_ACK) && write_data[0];

    always @(*) begin
        decoded_code = KEY_NONE;
        if (extended_pending) begin
            case (scan_code)
                8'h6b: decoded_code = KEY_LEFT;
                8'h74: decoded_code = KEY_RIGHT;
                default: decoded_code = KEY_NONE;
            endcase
        end else begin
            case (scan_code)
                8'h1c: decoded_code = KEY_LEFT;    // A
                8'h23: decoded_code = KEY_RIGHT;   // D
                8'h5a: decoded_code = KEY_CONFIRM; // Enter
                8'h29: decoded_code = KEY_CONFIRM; // Space
                8'h76: decoded_code = KEY_CANCEL;  // Esc
                8'h2d: decoded_code = KEY_RESTART; // R
                default: decoded_code = KEY_NONE;
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            key_ready <= 1'b0;
            key_code <= KEY_NONE;
        end else begin
            if (ack_write) begin
                key_ready <= 1'b0;
                key_code <= KEY_NONE;
            end

            if (scan_valid) begin
                if (scan_code == 8'he0) begin
                    extended_pending <= 1'b1;
                end else if (scan_code == 8'hf0) begin
                    break_pending <= 1'b1;
                end else if (break_pending) begin
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end else begin
                    if ((decoded_code != KEY_NONE) && (!key_ready || ack_write)) begin
                        key_ready <= 1'b1;
                        key_code <= decoded_code;
                    end
                    extended_pending <= 1'b0;
                end
            end
        end
    end

    always @(*) begin
        case (addr[11:0])
            ADDR_STATUS: read_data = {31'b0, key_ready};
            ADDR_CODE:   read_data = {24'b0, key_code};
            default:     read_data = 32'b0;
        endcase
    end
endmodule

`default_nettype wire
