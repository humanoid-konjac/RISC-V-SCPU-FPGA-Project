`timescale 1ns / 1ps
`default_nettype none

module vga_game_pattern(
    input wire clk, input wire rst, input wire frame_tick,
    input wire active_video, input wire [9:0] pixel_x, input wire [9:0] pixel_y,
    input wire [255:0] active_tubes, input wire [31:0] active_ui,
    input wire [31:0] active_meta, input wire [31:0] active_seed_lo,
    input wire [31:0] active_seed_hi,
    output reg [3:0] vga_r, output reg [3:0] vga_g, output reg [3:0] vga_b
);
    wire [2:0] cursor_index = active_ui[2:0];
    wire [2:0] selected_index = active_ui[6:4];
    wire selected_valid = active_ui[7];
    wire game_finished = active_ui[8];
    wire playing = active_ui[9];
    wire [3:0] tube_count = active_meta[7:4];
    reg [5:0] frame_counter;
    reg [2:0] tube_index;
    reg [9:0] tube_left, tube_x0, tube_stride;
    reg tube_span_valid;
    reg [31:0] tube_data;
    reg [1:0] liquid_layer;
    reg liquid_y_valid;
    reg [3:0] liquid_color;
    reg [11:0] liquid_rgb, pixel_rgb;
    integer i;
    wire text_on;
    wire [11:0] text_rgb;

    localparam [9:0] TUBE_WIDTH=48, TUBE_TOP=104, TUBE_BOTTOM=360;
    localparam [9:0] WALL_WIDTH=4, CURSOR_TOP=370, CURSOR_BOTTOM=378;

    wire tube_vertical_span = tube_span_valid && pixel_y>=TUBE_TOP && pixel_y<TUBE_BOTTOM;
    wire tube_wall_on = tube_vertical_span &&
        (pixel_x<tube_left+WALL_WIDTH || pixel_x>=tube_left+TUBE_WIDTH-WALL_WIDTH || pixel_y>=TUBE_BOTTOM-WALL_WIDTH);
    wire liquid_x_valid = tube_span_valid && pixel_x>=tube_left+5 && pixel_x<tube_left+43;
    wire liquid_on = liquid_x_valid && liquid_y_valid && liquid_color!=0;
    wire cursor_on = tube_span_valid && tube_index==cursor_index && pixel_y>=CURSOR_TOP && pixel_y<CURSOR_BOTTOM;
    wire selected_on = selected_valid && tube_span_valid && tube_index==selected_index;
    wire screen_border = pixel_x<8 || pixel_x>=632 || pixel_y<8 || pixel_y>=472;
    wire win_flash_on = playing && game_finished && !frame_counter[5] && screen_border;
    wire menu_panel = !playing && ((pixel_x>=150 && pixel_x<490 && (pixel_y>=55 && pixel_y<59 || pixel_y>=420 && pixel_y<424)) ||
                                  (pixel_y>=55 && pixel_y<424 && (pixel_x>=150 && pixel_x<154 || pixel_x>=486 && pixel_x<490)));

    vga_game_text U_TEXT(.pixel_x(pixel_x),.pixel_y(pixel_y),.active_ui(active_ui),
        .active_meta(active_meta),.active_seed_lo(active_seed_lo),.active_seed_hi(active_seed_hi),
        .text_on(text_on),.text_rgb(text_rgb));

    always @(posedge clk or posedge rst)
        if (rst) frame_counter<=0; else if (frame_tick) frame_counter<=frame_counter+1'b1;

    always @(*) begin
        case(tube_count)
            6: begin tube_x0=81; tube_stride=86; end
            7: begin tube_x0=62; tube_stride=78; end
            default: begin tube_x0=44; tube_stride=70; end
        endcase
        tube_index=0;tube_left=tube_x0;tube_span_valid=0;
        for(i=0;i<8;i=i+1) begin
            if(i<tube_count && pixel_x>=tube_x0+i*tube_stride && pixel_x<tube_x0+i*tube_stride+TUBE_WIDTH) begin
                tube_index=i[2:0];tube_left=tube_x0+i*tube_stride;tube_span_valid=1;
            end
        end
    end

    always @(*) begin
        case(tube_index)
            0:tube_data=active_tubes[31:0];1:tube_data=active_tubes[63:32];
            2:tube_data=active_tubes[95:64];3:tube_data=active_tubes[127:96];
            4:tube_data=active_tubes[159:128];5:tube_data=active_tubes[191:160];
            6:tube_data=active_tubes[223:192];default:tube_data=active_tubes[255:224];
        endcase
    end

    always @(*) begin
        liquid_layer=0;liquid_y_valid=1;
        if(pixel_y>=296 && pixel_y<TUBE_BOTTOM-WALL_WIDTH) liquid_layer=0;
        else if(pixel_y>=236 && pixel_y<296) liquid_layer=1;
        else if(pixel_y>=176 && pixel_y<236) liquid_layer=2;
        else if(pixel_y>=116 && pixel_y<176) liquid_layer=3;
        else liquid_y_valid=0;
        case(liquid_layer) 0:liquid_color=tube_data[3:0];1:liquid_color=tube_data[7:4];2:liquid_color=tube_data[11:8];default:liquid_color=tube_data[15:12];endcase
        case(liquid_color) 1:liquid_rgb=12'hf33;2:liquid_rgb=12'h3d3;3:liquid_rgb=12'h36f;
            4:liquid_rgb=12'hfd2;5:liquid_rgb=12'hb4f;6:liquid_rgb=12'h3dd;7:liquid_rgb=12'hf83;default:liquid_rgb=12'h123;endcase
    end

    always @(*) begin
        if(rst || !active_video) pixel_rgb=0;
        else if(win_flash_on) pixel_rgb=12'h3f3;
        else if(text_on) pixel_rgb=text_rgb;
        else if(menu_panel) pixel_rgb=12'h6cf;
        else if(playing && cursor_on) pixel_rgb=12'hfff;
        else if(playing && tube_wall_on) pixel_rgb=selected_on?12'hff0:12'hccc;
        else if(playing && liquid_on) pixel_rgb=liquid_rgb;
        else pixel_rgb=12'h123;
        vga_r=pixel_rgb[11:8];vga_g=pixel_rgb[7:4];vga_b=pixel_rgb[3:0];
    end
endmodule
`default_nettype wire
