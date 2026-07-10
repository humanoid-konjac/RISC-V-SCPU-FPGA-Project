`timescale 1ns/1ps

module ps2_keyboard_tb();
   reg clk;
   reg rst;
   reg ps2_clk;
   reg ps2_data;

   wire [7:0]  scan_code;
   wire        scan_valid;
   wire [31:0] display_hex;
   wire [7:0]  last_scan_code;
   wire [7:0]  last_ascii_code;
   wire        key_event;

   integer errors;

   ps2_keyboard U_PS2(
      .clk(clk),
      .rst(rst),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .scan_code(scan_code),
      .scan_valid(scan_valid)
   );

   keyboard_display U_DISPLAY(
      .clk(clk),
      .rst(rst),
      .scan_code(scan_code),
      .scan_valid(scan_valid),
      .display_hex(display_hex),
      .last_scan_code(last_scan_code),
      .last_ascii_code(last_ascii_code),
      .key_event(key_event)
   );

   task check32;
      input [255:0] name;
      input [31:0]  got;
      input [31:0]  expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%h expected=%h", name, got, expected);
         end
      end
   endtask

   task check8;
      input [255:0] name;
      input [7:0]   got;
      input [7:0]   expected;
      begin
         if (got !== expected) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%02h expected=%02h", name, got, expected);
         end
      end
   endtask

   task send_ps2_bit;
      input value;
      begin
         ps2_data = value;
         repeat (30) @(posedge clk);
         ps2_clk = 1'b0;
         repeat (30) @(posedge clk);
         ps2_clk = 1'b1;
         repeat (30) @(posedge clk);
      end
   endtask

   task send_ps2_frame;
      input [7:0] data;
      input       bad_parity;
      integer i;
      reg parity;
      begin
         parity = ~(^data);
         if (bad_parity)
            parity = ~parity;

         send_ps2_bit(1'b0);
         for (i = 0; i < 8; i = i + 1)
            send_ps2_bit(data[i]);
         send_ps2_bit(parity);
         send_ps2_bit(1'b1);

         ps2_data = 1'b1;
         repeat (80) @(posedge clk);
      end
   endtask

   initial begin
      $dumpfile("sim_out/ps2_keyboard.vcd");
      $dumpvars(0, ps2_keyboard_tb);

      clk = 1'b0;
      rst = 1'b1;
      ps2_clk = 1'b1;
      ps2_data = 1'b1;
      errors = 0;

      repeat (20) @(posedge clk);
      rst = 1'b0;
      repeat (20) @(posedge clk);

      send_ps2_frame(8'h1c, 1'b0); // A make
      check32("A display", display_hex, 32'h0041_001c);
      check8("A scan", last_scan_code, 8'h1c);
      check8("A ascii", last_ascii_code, 8'h41);

      send_ps2_frame(8'hf0, 1'b0); // break prefix
      send_ps2_frame(8'h1c, 1'b0); // A break, ignored
      check32("A break ignored", display_hex, 32'h0041_001c);

      send_ps2_frame(8'h16, 1'b0); // 1 make
      check32("1 display", display_hex, 32'h0031_0016);
      check8("1 ascii", last_ascii_code, 8'h31);

      send_ps2_frame(8'he0, 1'b0); // extended prefix
      check32("extended prefix ignored", display_hex, 32'h0031_0016);
      send_ps2_frame(8'h75, 1'b0); // Up arrow make
      check32("up display", display_hex, 32'h0055_0075);
      check8("up ascii", last_ascii_code, 8'h55);

      send_ps2_frame(8'h32, 1'b1); // bad parity, B ignored
      check32("bad parity ignored", display_hex, 32'h0055_0075);

      if (errors == 0)
         $display("PASS: ps2 keyboard display test completed");
      else
         $display("FAIL: ps2 keyboard display test completed with %0d error(s)", errors);

      $finish;
   end

   always #5 clk = ~clk;
endmodule
