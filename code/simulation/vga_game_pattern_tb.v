`timescale 1ns/1ps

module vga_game_pattern_tb;
    reg clk;
    reg rst;
    reg frame_tick;
    reg active_video;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg [255:0] active_tubes;
    reg [31:0] active_ui;
    reg [31:0] active_meta;
    reg [31:0] active_seed_lo;
    reg [31:0] active_seed_hi;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    integer errors;

    vga_game_pattern U_DUT(
        .clk(clk),
        .rst(rst),
        .frame_tick(frame_tick),
        .active_video(active_video),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .active_tubes(active_tubes),
        .active_ui(active_ui),
        .active_meta(active_meta),
        .active_seed_lo(active_seed_lo),
        .active_seed_hi(active_seed_hi),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );

    task check_pixel;
        input [255:0] name;
        input [9:0] x;
        input [9:0] y;
        input active;
        input [11:0] expected;
        begin
            pixel_x = x;
            pixel_y = y;
            active_video = active;
            #1;
            if ({vga_r, vga_g, vga_b} !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s got=%h expected=%h", name,
                         {vga_r, vga_g, vga_b}, expected);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        frame_tick = 1'b0;
        active_video = 1'b0;
        pixel_x = 10'b0;
        pixel_y = 10'b0;
        active_tubes = 256'b0;
        active_ui = 32'h00000200;
        active_meta = 32'h0021_0080;
        active_seed_lo = 32'h34567890;
        active_seed_hi = 32'h00000012;
        errors = 0;

        #1 check_pixel("reset black", 10'd50, 10'd320, 1'b1, 12'h000);
        rst = 1'b0;

        active_ui = 0;
        check_pixel("menu panel", 10'd150, 10'd56, 1'b1, 12'h6cf);
        check_pixel("menu title W", 10'd260, 10'd90, 1'b1, 12'hfff);
        check_pixel("menu seed first digit", 10'd284, 10'd220, 1'b1, 12'hfff);
        active_ui = 32'h00000200;

        // Tube 0 is [red, green, red, green] from bottom to top.
        active_tubes[31:0] = 32'h00002121;
        check_pixel("tube0 bottom red", 10'd50, 10'd320, 1'b1, 12'hf33);
        check_pixel("tube0 layer1 green", 10'd50, 10'd260, 1'b1, 12'h3d3);
        check_pixel("tube0 layer2 red", 10'd50, 10'd200, 1'b1, 12'hf33);
        check_pixel("tube0 top green", 10'd50, 10'd140, 1'b1, 12'h3d3);
        check_pixel("tube wall", 10'd45, 10'd200, 1'b1, 12'hccc);
        check_pixel("open tube top", 10'd60, 10'd102, 1'b1, 12'h123);

        active_tubes[3:0] = 4'd7;
        check_pixel("seventh color orange", 10'd50, 10'd320, 1'b1, 12'hf83);
        active_tubes[3:0] = 4'd1;

        // Tube 1 selected, tube 2 cursor, tube 6 empty.
        active_ui = 32'h00000292;
        check_pixel("selected wall", 10'd115, 10'd200, 1'b1, 12'hff0);
        check_pixel("cursor underline", 10'd190, 10'd373, 1'b1, 12'hfff);
        check_pixel("empty tube interior", 10'd470, 10'd320, 1'b1, 12'h123);
        check_pixel("background", 10'd20, 10'd200, 1'b1, 12'h123);
        check_pixel("blanking", 10'd50, 10'd320, 1'b0, 12'h000);

        active_ui = 32'h00000300;
        check_pixel("finished border flash", 10'd2, 10'd200, 1'b1, 12'h3f3);

        if (errors == 0)
            $display("PASS: VGA tube renderer test completed");
        else
            $display("FAIL: VGA tube renderer test completed with %0d error(s)", errors);
        $finish;
    end

    always #5 clk = ~clk;
endmodule
