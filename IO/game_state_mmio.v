`timescale 1ns / 1ps
`default_nettype none

module game_state_mmio(
    input  wire         clk,
    input  wire         rst,
    input  wire         write_en,
    input  wire [31:0]  addr,
    input  wire [31:0]  write_data,
    input  wire         frame_tick,
    output reg  [31:0]  read_data,
    output wire [255:0] active_tubes,
    output reg  [31:0]  active_ui,
    output reg  [31:0]  active_move_count
);
    localparam [11:0] ADDR_TUBE0 = 12'h020;
    localparam [11:0] ADDR_TUBE1 = 12'h024;
    localparam [11:0] ADDR_TUBE2 = 12'h028;
    localparam [11:0] ADDR_TUBE3 = 12'h02c;
    localparam [11:0] ADDR_TUBE4 = 12'h030;
    localparam [11:0] ADDR_TUBE5 = 12'h034;
    localparam [11:0] ADDR_TUBE6 = 12'h038;
    localparam [11:0] ADDR_TUBE7 = 12'h03c;
    localparam [11:0] ADDR_UI    = 12'h040;
    localparam [11:0] ADDR_MOVES = 12'h044;
    localparam [11:0] ADDR_COMMIT = 12'h048;

    reg [31:0] shadow_tube [0:7];
    reg [31:0] pending_tube [0:7];
    reg [31:0] active_tube [0:7];
    reg [31:0] shadow_ui;
    reg [31:0] shadow_move_count;
    reg [31:0] pending_ui;
    reg [31:0] pending_move_count;
    reg        commit_pending;
    integer i;

    genvar tube_index;
    generate
        for (tube_index = 0; tube_index < 8; tube_index = tube_index + 1) begin : PACK_ACTIVE_TUBES
            assign active_tubes[tube_index * 32 +: 32] = active_tube[tube_index];
        end
    endgenerate

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shadow_ui <= 32'b0;
            shadow_move_count <= 32'b0;
            pending_ui <= 32'b0;
            pending_move_count <= 32'b0;
            active_ui <= 32'b0;
            active_move_count <= 32'b0;
            commit_pending <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                shadow_tube[i] <= 32'b0;
                pending_tube[i] <= 32'b0;
                active_tube[i] <= 32'b0;
            end
        end else begin
            if (frame_tick && commit_pending) begin
                for (i = 0; i < 8; i = i + 1)
                    active_tube[i] <= pending_tube[i];
                active_ui <= pending_ui;
                active_move_count <= pending_move_count;
                commit_pending <= 1'b0;
            end

            if (write_en) begin
                case (addr[11:0])
                    ADDR_TUBE0: shadow_tube[0] <= write_data;
                    ADDR_TUBE1: shadow_tube[1] <= write_data;
                    ADDR_TUBE2: shadow_tube[2] <= write_data;
                    ADDR_TUBE3: shadow_tube[3] <= write_data;
                    ADDR_TUBE4: shadow_tube[4] <= write_data;
                    ADDR_TUBE5: shadow_tube[5] <= write_data;
                    ADDR_TUBE6: shadow_tube[6] <= write_data;
                    ADDR_TUBE7: shadow_tube[7] <= write_data;
                    ADDR_UI: shadow_ui <= write_data;
                    ADDR_MOVES: shadow_move_count <= write_data;
                    ADDR_COMMIT: begin
                        for (i = 0; i < 8; i = i + 1)
                            pending_tube[i] <= shadow_tube[i];
                        pending_ui <= shadow_ui;
                        pending_move_count <= shadow_move_count;
                        commit_pending <= 1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        case (addr[11:0])
            ADDR_TUBE0: read_data = shadow_tube[0];
            ADDR_TUBE1: read_data = shadow_tube[1];
            ADDR_TUBE2: read_data = shadow_tube[2];
            ADDR_TUBE3: read_data = shadow_tube[3];
            ADDR_TUBE4: read_data = shadow_tube[4];
            ADDR_TUBE5: read_data = shadow_tube[5];
            ADDR_TUBE6: read_data = shadow_tube[6];
            ADDR_TUBE7: read_data = shadow_tube[7];
            ADDR_UI: read_data = shadow_ui;
            ADDR_MOVES: read_data = shadow_move_count;
            default: read_data = 32'b0;
        endcase
    end
endmodule

`default_nettype wire
