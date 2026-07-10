`timescale 1ns/1ps

module vga_game_pattern_tb;
    reg rst;
    reg active_video;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg [255:0] active_tubes;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    integer errors;

    vga_game_pattern U_DUT(
        .rst(rst),
        .active_video(active_video),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .active_tubes(active_tubes),
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
        rst = 1'b1;
        active_video = 1'b0;
        pixel_x = 10'b0;
        pixel_y = 10'b0;
        active_tubes = 256'b0;
        errors = 0;

        #1 check_pixel("reset black", 10'd320, 10'd240, 1'b1, 12'h000);
        rst = 1'b0;
        active_tubes[3:0] = 4'd1;
        check_pixel("red block", 10'd320, 10'd240, 1'b1, 12'hf33);
        check_pixel("white border", 10'd257, 10'd240, 1'b1, 12'hfff);
        check_pixel("background", 10'd100, 10'd100, 1'b1, 12'h123);
        check_pixel("blanking", 10'd320, 10'd240, 1'b0, 12'h000);
        active_tubes[3:0] = 4'd6;
        check_pixel("cyan block", 10'd320, 10'd240, 1'b1, 12'h3dd);

        if (errors == 0)
            $display("PASS: VGA game pattern test completed");
        else
            $display("FAIL: VGA game pattern test completed with %0d error(s)", errors);
        $finish;
    end
endmodule
