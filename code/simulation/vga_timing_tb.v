`timescale 1ns/1ps

module vga_timing_tb();
   reg clk;
   reg rst;

   wire       pixel_tick;
   wire [9:0] pixel_x;
   wire [9:0] pixel_y;
   wire       active_video;
   wire       frame_tick;
   wire       hsync;
   wire       vsync;

   integer errors;
   integer i;
   integer row;
   integer active_pixels;
   integer hsync_low_pixels;
   integer active_rows;
   integer vsync_low_rows;
   integer tick_cycle;
   integer last_tick_cycle;
   integer tick_count;
   integer guard;

   vga_timing U_VGA_TIMING(
      .clk(clk),
      .rst(rst),
      .pixel_tick(pixel_tick),
      .pixel_x(pixel_x),
      .pixel_y(pixel_y),
      .active_video(active_video),
      .frame_tick(frame_tick),
      .hsync(hsync),
      .vsync(vsync)
   );

   task fail;
      input [255:0] name;
      begin
         errors = errors + 1;
         $display("FAIL: %0s", name);
      end
   endtask

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

   task check_int;
      input [255:0] name;
      input integer got;
      input integer expected;
      begin
         if (got != expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%0d expected=%0d", name, got, expected);
         end
      end
   endtask

   task wait_pixel_tick;
      begin
         @(negedge clk);
         while (!pixel_tick)
            @(negedge clk);
         #1;
      end
   endtask

   task wait_pixel;
      input [9:0] x;
      input [9:0] y;
      begin
         guard = 0;
         while (!pixel_tick || pixel_x !== x || pixel_y !== y) begin
            @(negedge clk);
            guard = guard + 1;
            if (guard > 1700000) begin
               fail("timeout while waiting for requested VGA pixel");
               guard = 0;
               disable wait_pixel;
            end
         end
         #1;
      end
   endtask

   task wait_row_start;
      input [9:0] y;
      begin
         guard = 0;
         while (!pixel_tick || pixel_x !== 10'd0 || pixel_y !== y) begin
            @(negedge clk);
            guard = guard + 1;
            if (guard > 1700000) begin
               fail("timeout while waiting for requested VGA row");
               guard = 0;
               disable wait_row_start;
            end
         end
         #1;
      end
   endtask

   initial begin
      $dumpfile("sim_out/vga_timing.vcd");
      $dumpvars(0, vga_timing_tb);

      clk = 1'b0;
      rst = 1'b1;
      errors = 0;

      repeat (8) @(posedge clk);
      @(negedge clk);
      rst = 1'b0;

      tick_cycle = 0;
      last_tick_cycle = -1;
      tick_count = 0;
      repeat (40) begin
         @(negedge clk);
         if (pixel_tick) begin
            if (last_tick_cycle >= 0)
               check_int("pixel_tick period", tick_cycle - last_tick_cycle, 4);
            last_tick_cycle = tick_cycle;
            tick_count = tick_count + 1;
         end
         tick_cycle = tick_cycle + 1;
      end
      if (tick_count < 8)
         fail("pixel_tick did not appear often enough");

      wait_pixel(10'd0, 10'd0);

      active_pixels = 0;
      hsync_low_pixels = 0;
      for (i = 0; i < 800; i = i + 1) begin
         check10("horizontal pixel_x", pixel_x, i[9:0]);
         check10("horizontal pixel_y", pixel_y, 10'd0);

         if (active_video)
            active_pixels = active_pixels + 1;
         if (!hsync)
            hsync_low_pixels = hsync_low_pixels + 1;

         if (i < 640)
            check1("active_video in visible horizontal region", active_video, 1'b1);
         else
            check1("active_video outside visible horizontal region", active_video, 1'b0);

         if ((i >= 656) && (i < 752))
            check1("hsync low interval", hsync, 1'b0);
         else
            check1("hsync high interval", hsync, 1'b1);

         if (i != 799)
            wait_pixel_tick();
      end
      check_int("active pixels per line", active_pixels, 640);
      check_int("hsync low pixels per line", hsync_low_pixels, 96);

      wait_row_start(10'd0);
      active_rows = 0;
      vsync_low_rows = 0;
      for (row = 0; row < 525; row = row + 1) begin
         check10("vertical row start x", pixel_x, 10'd0);
         check10("vertical row", pixel_y, row[9:0]);

         if (active_video)
            active_rows = active_rows + 1;
         if (!vsync)
            vsync_low_rows = vsync_low_rows + 1;

         if (row < 480)
            check1("active_video in visible vertical region", active_video, 1'b1);
         else
            check1("active_video outside visible vertical region", active_video, 1'b0);

         if ((row >= 490) && (row < 492))
            check1("vsync low interval", vsync, 1'b0);
         else
            check1("vsync high interval", vsync, 1'b1);

         if (row != 524)
            wait_row_start((row + 1) & 10'h3ff);
      end
      check_int("active rows per frame", active_rows, 480);
      check_int("vsync low rows per frame", vsync_low_rows, 2);

      guard = 0;
      while (!frame_tick && (guard <= 4000)) begin
         @(negedge clk);
         guard = guard + 1;
      end
      if (!frame_tick) begin
         fail("frame_tick did not occur near end of frame");
      end else begin
         check10("frame_tick x", pixel_x, 10'd799);
         check10("frame_tick y", pixel_y, 10'd524);
      end

      if (errors == 0)
         $display("PASS: vga timing test completed");
      else
         $display("FAIL: vga timing test completed with %0d error(s)", errors);

      $finish;
   end

   always #5 clk = ~clk;
endmodule
