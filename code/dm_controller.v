`timescale 1ns/1ps

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
    localparam [2:0] dm_word              = 3'b000;
    localparam [2:0] dm_halfword          = 3'b001;
    localparam [2:0] dm_halfword_unsigned = 3'b010;
    localparam [2:0] dm_byte              = 3'b011;
    localparam [2:0] dm_byte_unsigned     = 3'b100;

    wire [1:0] byte_offset = Addr_in[1:0];

    always @(*) begin
        case (dm_ctrl)
            dm_byte: begin
                case (byte_offset)
                    2'b00: Data_read = {{24{Data_read_from_dm[7]}},  Data_read_from_dm[7:0]};
                    2'b01: Data_read = {{24{Data_read_from_dm[15]}}, Data_read_from_dm[15:8]};
                    2'b10: Data_read = {{24{Data_read_from_dm[23]}}, Data_read_from_dm[23:16]};
                    default: Data_read = {{24{Data_read_from_dm[31]}}, Data_read_from_dm[31:24]};
                endcase
            end

            dm_byte_unsigned: begin
                case (byte_offset)
                    2'b00: Data_read = {24'b0, Data_read_from_dm[7:0]};
                    2'b01: Data_read = {24'b0, Data_read_from_dm[15:8]};
                    2'b10: Data_read = {24'b0, Data_read_from_dm[23:16]};
                    default: Data_read = {24'b0, Data_read_from_dm[31:24]};
                endcase
            end

            dm_halfword: begin
                if (Addr_in[1])
                    Data_read = {{16{Data_read_from_dm[31]}}, Data_read_from_dm[31:16]};
                else
                    Data_read = {{16{Data_read_from_dm[15]}}, Data_read_from_dm[15:0]};
            end

            dm_halfword_unsigned: begin
                if (Addr_in[1])
                    Data_read = {16'b0, Data_read_from_dm[31:16]};
                else
                    Data_read = {16'b0, Data_read_from_dm[15:0]};
            end

            default: begin
                Data_read = Data_read_from_dm;
            end
        endcase
    end

    always @(*) begin
        case (dm_ctrl)
            dm_byte,
            dm_byte_unsigned: begin
                case (byte_offset)
                    2'b00: Data_write_to_dm = {24'b0, Data_write[7:0]};
                    2'b01: Data_write_to_dm = {16'b0, Data_write[7:0], 8'b0};
                    2'b10: Data_write_to_dm = {8'b0, Data_write[7:0], 16'b0};
                    default: Data_write_to_dm = {Data_write[7:0], 24'b0};
                endcase
            end

            dm_halfword,
            dm_halfword_unsigned: begin
                if (Addr_in[1])
                    Data_write_to_dm = {Data_write[15:0], 16'b0};
                else
                    Data_write_to_dm = {16'b0, Data_write[15:0]};
            end

            default: begin
                Data_write_to_dm = Data_write;
            end
        endcase
    end

    always @(*) begin
        if (!mem_w) begin
            wea_mem = 4'b0000;
        end else begin
            case (dm_ctrl)
                dm_byte,
                dm_byte_unsigned: begin
                    case (byte_offset)
                        2'b00: wea_mem = 4'b0001;
                        2'b01: wea_mem = 4'b0010;
                        2'b10: wea_mem = 4'b0100;
                        default: wea_mem = 4'b1000;
                    endcase
                end

                dm_halfword,
                dm_halfword_unsigned: begin
                    wea_mem = Addr_in[1] ? 4'b1100 : 4'b0011;
                end

                default: begin
                    wea_mem = 4'b1111;
                end
            endcase
        end
    end

endmodule
