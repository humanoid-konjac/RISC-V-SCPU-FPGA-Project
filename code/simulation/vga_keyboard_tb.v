`timescale 1ns/1ps

module vga_keyboard_tb();
   reg clk;
   reg rst;

   reg  [7:0] scan_code;
   reg        scan_valid;
   wire       k_move_up;
   wire       k_move_down;
   wire       k_move_left;
   wire       k_move_right;
   wire       k_jump;

   reg        pixel_tick;
   reg        active_video;
   reg  [9:0] pixel_x;
   reg  [9:0] pixel_y;
   reg        enable_sprite;
   reg        move_up;
   reg        move_down;
   reg        move_left;
   reg        move_right;
   wire [3:0] vga_r;
   wire [3:0] vga_g;
   wire [3:0] vga_b;
   wire [9:0] sprite_x;
   wire [9:0] sprite_y;

   integer errors;
   integer i;

   keyboard_control U_KEYBOARD_CONTROL(
      .clk(clk),
      .rst(rst),
      .scan_code(scan_code),
      .scan_valid(scan_valid),
      .move_up(k_move_up),
      .move_down(k_move_down),
      .move_left(k_move_left),
      .move_right(k_move_right),
      .jump(k_jump)
   );

   vga_test_pattern U_VGA_TEST_PATTERN(
      .clk(clk),
      .rst(rst),
      .pixel_tick(pixel_tick),
      .active_video(active_video),
      .pixel_x(pixel_x),
      .pixel_y(pixel_y),
      .enable_sprite(enable_sprite),
      .move_up(move_up),
      .move_down(move_down),
      .move_left(move_left),
      .move_right(move_right),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .sprite_x(sprite_x),
      .sprite_y(sprite_y)
   );

   task check1;
      input [255:0] name;
      input          got;
      input          expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%b expected=%b", name, got, expected);
         end
      end
   endtask

   task check10;
      input [255:0] name;
      input [9:0]   got;
      input [9:0]   expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%0d expected=%0d", name, got, expected);
         end
      end
   endtask

   task check12;
      input [255:0] name;
      input [11:0]  got;
      input [11:0]  expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%03h expected=%03h", name, got, expected);
         end
      end
   endtask

   task send_scan;
      input [7:0] code;
      begin
         @(negedge clk);
         scan_code = code;
         scan_valid = 1'b1;
         @(posedge clk);
         #1;
         scan_valid = 1'b0;
      end
   endtask

   task pulse_move;
      input [1:0] dir;
      begin
         @(negedge clk);
         move_up = (dir == 2'd0);
         move_down = (dir == 2'd1);
         move_left = (dir == 2'd2);
         move_right = (dir == 2'd3);
         @(posedge clk);
         #1;
         move_up = 1'b0;
         move_down = 1'b0;
         move_left = 1'b0;
         move_right = 1'b0;
      end
   endtask

   task draw_pixel;
      input [9:0] x;
      input [9:0] y;
      input       active;
      input       sprite_en;
      begin
         @(negedge clk);
         pixel_x = x;
         pixel_y = y;
         active_video = active;
         enable_sprite = sprite_en;
         pixel_tick = 1'b1;
         @(posedge clk);
         #1;
         pixel_tick = 1'b0;
      end
   endtask

   initial begin
      $dumpfile("sim_out/vga_keyboard.vcd");
      $dumpvars(0, vga_keyboard_tb);

      clk = 1'b0;
      rst = 1'b1;
      scan_code = 8'h00;
      scan_valid = 1'b0;
      pixel_tick = 1'b0;
      active_video = 1'b0;
      pixel_x = 10'd0;
      pixel_y = 10'd0;
      enable_sprite = 1'b0;
      move_up = 1'b0;
      move_down = 1'b0;
      move_left = 1'b0;
      move_right = 1'b0;
      errors = 0;

      repeat (5) @(posedge clk);
      rst = 1'b0;
      repeat (2) @(posedge clk);

      send_scan(8'he0);
      check1("E0 prefix no move", k_move_up | k_move_down | k_move_left | k_move_right, 1'b0);
      send_scan(8'h75);
      check1("up arrow move", k_move_up, 1'b1);

      send_scan(8'he0);
      send_scan(8'hf0);
      send_scan(8'h75);
      check1("up arrow break ignored", k_move_up | k_move_down | k_move_left | k_move_right, 1'b0);

      send_scan(8'h1d);
      check1("W move", k_move_up, 1'b1);
      check1("W jump", k_jump, 1'b1);
      send_scan(8'h1d);
      check1("W typematic still moves", k_move_up, 1'b1);
      check1("W typematic jump ignored", k_jump, 1'b0);
      send_scan(8'hf0);
      send_scan(8'h1d);
      check1("W break ignored", k_move_up, 1'b0);
      check1("W break jump ignored", k_jump, 1'b0);
      send_scan(8'h1d);
      check1("W press after release", k_move_up, 1'b1);
      check1("W jump after release", k_jump, 1'b1);
      send_scan(8'h29);
      check1("space jump", k_jump, 1'b1);
      send_scan(8'h1b);
      check1("S move", k_move_down, 1'b1);
      send_scan(8'h1c);
      check1("A move", k_move_left, 1'b1);
      send_scan(8'h23);
      check1("D move", k_move_right, 1'b1);

      check10("sprite initial x", sprite_x, 10'd304);
      check10("sprite initial y", sprite_y, 10'd224);

      pulse_move(2'd3);
      check10("sprite right", sprite_x, 10'd312);
      pulse_move(2'd2);
      check10("sprite left", sprite_x, 10'd304);
      pulse_move(2'd0);
      check10("sprite up", sprite_y, 10'd216);
      pulse_move(2'd1);
      check10("sprite down", sprite_y, 10'd224);

      for (i = 0; i < 100; i = i + 1)
         pulse_move(2'd2);
      check10("sprite left saturated", sprite_x, 10'd0);
      for (i = 0; i < 100; i = i + 1)
         pulse_move(2'd0);
      check10("sprite up saturated", sprite_y, 10'd0);
      for (i = 0; i < 100; i = i + 1)
         pulse_move(2'd3);
      check10("sprite right saturated", sprite_x, 10'd608);
      for (i = 0; i < 100; i = i + 1)
         pulse_move(2'd1);
      check10("sprite down saturated", sprite_y, 10'd448);

      rst = 1'b1;
      repeat (2) @(posedge clk);
      rst = 1'b0;
      repeat (2) @(posedge clk);

      draw_pixel(10'd314, 10'd234, 1'b1, 1'b0);
      check12("sprite disabled shows color bar", {vga_r, vga_g, vga_b}, 12'hff0);
      draw_pixel(10'd314, 10'd234, 1'b1, 1'b1);
      check12("sprite enabled shows sprite body", {vga_r, vga_g, vga_b}, 12'hf80);
      draw_pixel(10'd305, 10'd225, 1'b1, 1'b1);
      check12("sprite border", {vga_r, vga_g, vga_b}, 12'hfff);
      draw_pixel(10'd0, 10'd20, 1'b1, 1'b0);
      check12("screen border", {vga_r, vga_g, vga_b}, 12'hfff);
      draw_pixel(10'd320, 10'd20, 1'b1, 1'b0);
      check12("center line", {vga_r, vga_g, vga_b}, 12'hfff);
      draw_pixel(10'd100, 10'd20, 1'b0, 1'b1);
      check12("inactive video black", {vga_r, vga_g, vga_b}, 12'h000);

      if (errors == 0)
         $display("PASS: vga keyboard and pattern test completed");
      else
         $display("FAIL: vga keyboard and pattern test completed with %0d error(s)", errors);

      $finish;
   end

   always #5 clk = ~clk;
endmodule
