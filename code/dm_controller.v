`timescale 1ns / 1ps
`default_nettype none

module dm_controller(
    input  wire        mem_w,
    input  wire [31:0] Addr_in,
    input  wire [31:0] Data_write,
    input  wire [2:0]  dm_ctrl,
    input  wire [31:0] Data_read_from_dm,
    output reg  [31:0] Data_read,
    output reg  [31:0] Data_write_to_dm,
    output reg  [3:0]  wea_mem
);
    localparam [2:0] DM_WORD  = 3'b000;
    localparam [2:0] DM_HALF  = 3'b001;
    localparam [2:0] DM_UHALF = 3'b010;
    localparam [2:0] DM_BYTE  = 3'b011;
    localparam [2:0] DM_UBYTE = 3'b100;

    wire [1:0] byte_offset = Addr_in[1:0];
    wire       half_offset = Addr_in[1];

    reg [7:0]  selected_byte;
    reg [15:0] selected_half;

    always @(*) begin
        case (byte_offset)
            2'b00: selected_byte = Data_read_from_dm[7:0];
            2'b01: selected_byte = Data_read_from_dm[15:8];
            2'b10: selected_byte = Data_read_from_dm[23:16];
            default: selected_byte = Data_read_from_dm[31:24];
        endcase

        selected_half = half_offset ? Data_read_from_dm[31:16] : Data_read_from_dm[15:0];

        case (dm_ctrl)
            DM_BYTE:  Data_read = {{24{selected_byte[7]}}, selected_byte};
            DM_UBYTE: Data_read = {24'b0, selected_byte};
            DM_HALF:  Data_read = {{16{selected_half[15]}}, selected_half};
            DM_UHALF: Data_read = {16'b0, selected_half};
            default:  Data_read = Data_read_from_dm;
        endcase
    end

    always @(*) begin
        Data_write_to_dm = 32'b0;
        wea_mem = 4'b0000;

        if (mem_w) begin
            case (dm_ctrl)
                DM_BYTE, DM_UBYTE: begin
                    Data_write_to_dm = {4{Data_write[7:0]}};
                    wea_mem = 4'b0001 << byte_offset;
                end

                DM_HALF, DM_UHALF: begin
                    Data_write_to_dm = {2{Data_write[15:0]}};
                    wea_mem = half_offset ? 4'b1100 : 4'b0011;
                end

                default: begin
                    Data_write_to_dm = Data_write;
                    wea_mem = 4'b1111;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
