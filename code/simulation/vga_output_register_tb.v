`timescale 1ns/1ps

module vga_output_register_tb;
    reg clk;
    reg rst;
    reg [11:0] rgb_in;
    reg hsync_in;
    reg vsync_in;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire hsync_out;
    wire vsync_out;
    integer errors;

    vga_output_register U_DUT(
        .clk(clk),
        .rst(rst),
        .rgb_in(rgb_in),
        .hsync_in(hsync_in),
        .vsync_in(vsync_in),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync_out(hsync_out),
        .vsync_out(vsync_out)
    );

    task check_outputs;
        input [255:0] name;
        input [11:0] expected_rgb;
        input expected_hsync;
        input expected_vsync;
        begin
            if ({vga_r, vga_g, vga_b} !== expected_rgb ||
                hsync_out !== expected_hsync || vsync_out !== expected_vsync) begin
                errors = errors + 1;
                $display("FAIL: %0s rgb=%h/%h hs=%b/%b vs=%b/%b", name,
                         {vga_r, vga_g, vga_b}, expected_rgb,
                         hsync_out, expected_hsync, vsync_out, expected_vsync);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        rgb_in = 12'habc;
        hsync_in = 1'b0;
        vsync_in = 1'b0;
        errors = 0;

        #1 check_outputs("asynchronous reset", 12'h000, 1'b1, 1'b1);
        @(negedge clk);
        rst = 1'b0;
        rgb_in = 12'hf00;
        hsync_in = 1'b1;
        vsync_in = 1'b0;
        @(posedge clk);
        #1 check_outputs("registered sample", 12'hf00, 1'b1, 1'b0);

        // Combinational decode glitches between clock edges must not reach pins.
        #1 rgb_in = 12'hfff;
        #1 rgb_in = 12'h000;
        #1 hsync_in = 1'b0;
        #1 vsync_in = 1'b1;
        #1 check_outputs("mid-cycle glitches blocked", 12'hf00, 1'b1, 1'b0);

        rgb_in = 12'h3dd;
        hsync_in = 1'b0;
        vsync_in = 1'b1;
        @(posedge clk);
        #1 check_outputs("next stable sample", 12'h3dd, 1'b0, 1'b1);

        if (errors == 0)
            $display("PASS: VGA output register test completed");
        else
            $display("FAIL: VGA output register test completed with %0d error(s)", errors);
        $finish;
    end

    always #5 clk = ~clk;
endmodule
