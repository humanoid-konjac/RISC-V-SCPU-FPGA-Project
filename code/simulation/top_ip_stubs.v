`timescale 1ns/1ps

// Simulation-only behavioral replacements for Vivado IP and EDF netlists.
// Do not add this file to the Vivado design source set.

module ROM_D(input wire [9:0] a, output wire [31:0] spo);
    reg [31:0] memory [0:1023];
    assign spo = memory[a];
endmodule

module RAM_B(
    input wire [9:0] addra,
    input wire clka,
    input wire [31:0] dina,
    input wire [3:0] wea,
    output wire [31:0] douta
);
    reg [31:0] memory [0:1023];
    assign douta = memory[addra];
    always @(posedge clka) begin
        if (wea[0]) memory[addra][7:0] <= dina[7:0];
        if (wea[1]) memory[addra][15:8] <= dina[15:8];
        if (wea[2]) memory[addra][23:16] <= dina[23:16];
        if (wea[3]) memory[addra][31:24] <= dina[31:24];
    end
endmodule

module Multi_8CH32(
    input wire clk, input wire rst, input wire EN,
    input wire [2:0] Switch,
    input wire [63:0] point_in, input wire [63:0] LES,
    input wire [31:0] data0, input wire [31:0] data1,
    input wire [31:0] data2, input wire [31:0] data3,
    input wire [31:0] data4, input wire [31:0] data5,
    input wire [31:0] data6, input wire [31:0] data7,
    output reg [7:0] point_out, output reg [7:0] LE_out,
    output reg [31:0] Disp_num
);
    always @(*) begin
        point_out = point_in[7:0];
        LE_out = LES[7:0];
        case (Switch)
            3'd0: Disp_num = data0;
            3'd1: Disp_num = data1;
            3'd2: Disp_num = data2;
            3'd3: Disp_num = data3;
            3'd4: Disp_num = data4;
            3'd5: Disp_num = data5;
            3'd6: Disp_num = data6;
            default: Disp_num = data7;
        endcase
    end
endmodule

module SPIO(
    input wire clk, input wire rst, input wire EN,
    input wire [31:0] P_Data,
    output wire [1:0] counter_set,
    output reg [15:0] LED_out,
    output wire [15:0] led,
    output wire [13:0] GPIOf0
);
    assign counter_set = LED_out[1:0];
    assign led = LED_out;
    assign GPIOf0 = LED_out[15:2];
    always @(posedge clk or posedge rst) begin
        if (rst)
            LED_out <= 16'b0;
        else if (EN)
            LED_out <= P_Data[15:0];
    end
endmodule

module SSeg7(
    input wire clk, input wire rst, input wire SW0, input wire flash,
    input wire [31:0] Hexs, input wire [7:0] point,
    input wire [7:0] LES,
    output wire [7:0] seg_an, output wire [7:0] seg_sout
);
    assign seg_an = 8'hfe;
    assign seg_sout = Hexs[7:0] ^ point ^ LES ^ {8{SW0 & flash}};
endmodule
