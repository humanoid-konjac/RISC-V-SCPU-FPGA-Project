`timescale 1ns/1ps

module water_sort_firmware_tb;
    reg clk;
    reg rst;
    reg [7:0] scan_code;
    reg scan_valid;
    reg frame_tick;

    wire [31:0] inst;
    wire [31:0] pc;
    wire [31:0] addr;
    wire [31:0] cpu_write_data;
    wire [31:0] cpu_read_data;
    wire mem_w;
    wire [2:0] dm_ctrl;
    wire cpu_mio;

    wire ram_access = (addr[31:12] == 20'h00000) ||
                      (addr[31:12] == 20'h10000);
    wire game_access = (addr[31:12] == 20'hd0000);
    wire game_write_en = mem_w && game_access;

    wire [31:0] ram_read_word;
    wire [31:0] ram_read_data;
    wire [31:0] ram_write_data;
    wire [3:0] ram_write_enable;
    wire [31:0] keyboard_read_data;
    wire [31:0] state_read_data;
    wire [31:0] game_read_data = keyboard_read_data | state_read_data;
    wire key_ready;
    wire [7:0] key_code;
    wire [255:0] active_tubes;
    wire [31:0] active_ui;
    wire [31:0] active_move_count;
    wire [31:0] active_meta;
    wire [31:0] active_level;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    reg [31:0] led_value;
    reg [31:0] display_value;
    reg [255:0] initial_tubes;
    integer source_index;
    integer target_index;
    integer i;
    integer errors;
    integer cursor_model;

    assign inst = imem[pc[11:2]];
    assign ram_read_word = dmem[addr[11:2]];
    assign cpu_read_data = ram_access ? ram_read_data :
                           (game_access ? game_read_data : 32'b0);

    SCPU U_SCPU(
        .clk(clk),
        .reset(rst),
        .en(1'b1),
        .MIO_ready(1'b1),
        .inst_in(inst),
        .Data_in(cpu_read_data),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr),
        .Data_out(cpu_write_data),
        .dm_ctrl(dm_ctrl),
        .CPU_MIO(cpu_mio),
        .INT(1'b0)
    );

    dm_controller U_DM_CONTROLLER(
        .mem_w(mem_w),
        .Addr_in(addr),
        .Data_write(cpu_write_data),
        .dm_ctrl(dm_ctrl),
        .Data_read_from_dm(ram_read_word),
        .Data_read(ram_read_data),
        .Data_write_to_dm(ram_write_data),
        .wea_mem(ram_write_enable)
    );

    keyboard_event_mmio U_KEYBOARD_EVENT(
        .clk(clk),
        .rst(rst),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .write_en(game_write_en),
        .addr(addr),
        .write_data(cpu_write_data),
        .read_data(keyboard_read_data),
        .key_ready(key_ready),
        .key_code(key_code)
    );

    game_state_mmio U_GAME_STATE(
        .clk(clk),
        .rst(rst),
        .write_en(game_write_en),
        .addr(addr),
        .write_data(cpu_write_data),
        .frame_tick(frame_tick),
        .read_data(state_read_data),
        .active_tubes(active_tubes),
        .active_ui(active_ui),
        .active_move_count(active_move_count),
        .active_meta(active_meta),
        .active_level(active_level)
    );

    always @(posedge clk) begin
        if (ram_access && mem_w) begin
            if (ram_write_enable[0]) dmem[addr[11:2]][7:0] <= ram_write_data[7:0];
            if (ram_write_enable[1]) dmem[addr[11:2]][15:8] <= ram_write_data[15:8];
            if (ram_write_enable[2]) dmem[addr[11:2]][23:16] <= ram_write_data[23:16];
            if (ram_write_enable[3]) dmem[addr[11:2]][31:24] <= ram_write_data[31:24];
        end
        if (mem_w && (addr[31:28] == 4'he))
            display_value <= cpu_write_data;
        if (mem_w && (addr[31:28] == 4'hf))
            led_value <= cpu_write_data;
    end

    task check32;
        input [255:0] name;
        input [31:0] got;
        input [31:0] expected;
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s got=%h expected=%h", name, got, expected);
            end
        end
    endtask

    task pulse_frame;
        begin
            @(negedge clk);
            frame_tick = 1'b1;
            @(posedge clk);
            #1 frame_tick = 1'b0;
        end
    endtask

    task send_scan_and_wait;
        input [7:0] code;
        integer timeout;
        begin
            @(negedge clk);
            scan_code = code;
            scan_valid = 1'b1;
            @(posedge clk);
            #1 scan_valid = 1'b0;

            timeout = 0;
            while (key_ready && timeout < 5000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout == 5000) begin
                errors = errors + 1;
                $display("FAIL: CPU did not acknowledge scan code %h", code);
            end
        end
    endtask

    task move_cursor_to;
        input [2:0] target;
        begin
            while (cursor_model != target) begin
                send_scan_and_wait(8'h23); // D / right
                cursor_model = (cursor_model + 1) & 7;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        scan_code = 8'b0;
        scan_valid = 1'b0;
        frame_tick = 1'b0;
        led_value = 32'b0;
        display_value = 32'b0;
        errors = 0;
        cursor_model = 0;

        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'b0;
        end
        $readmemh("software/water_sort/fpga/build/water_sort_game_i.mem", imem);
        $readmemh("software/water_sort/fpga/build/water_sort_game_d.mem", dmem);

        repeat (5) @(posedge clk);
        rst = 1'b0;

        // Firmware boots into the menu at NORMAL difficulty.
        wait (led_value == 32'h00000002);
        pulse_frame();
        check32("menu UI", active_ui, 32'h0);
        check32("normal menu meta", active_meta & 32'hff, 32'h71);

        // Invalid level 99 is rejected and remains in the menu.
        send_scan_and_wait(8'h46);
        send_scan_and_wait(8'h46);
        send_scan_and_wait(8'h5a);
        pulse_frame();
        check32("invalid level stays in menu", active_ui & 32'h00000a00,
                32'h00000800);
        check32("invalid level BCD", active_level, 32'h00000099);
        send_scan_and_wait(8'h66);
        send_scan_and_wait(8'h66);

        // Type level 12, select HARD with S/down, and start.
        send_scan_and_wait(8'h16);
        send_scan_and_wait(8'h1e);
        send_scan_and_wait(8'h1b);
        send_scan_and_wait(8'h5a);
        pulse_frame();
        check32("playing UI", active_ui, 32'h00000200);
        check32("hard game meta", active_meta & 32'hff, 32'h82);
        check32("level BCD", active_level, 32'h00000012);
        initial_tubes = active_tubes;

        source_index = -1;
        target_index = -1;
        for (i = 0; i < 8; i = i + 1) begin
            if (active_tubes[i*32 +: 16] == 0)
                target_index = i;
            else if (source_index < 0)
                source_index = i;
        end
        if (source_index < 0 || target_index < 0) begin
            errors = errors + 1;
            $display("FAIL: generated game lacks source or empty target");
        end else begin
            move_cursor_to(source_index[2:0]);
            send_scan_and_wait(8'h5a);
            move_cursor_to(target_index[2:0]);
            send_scan_and_wait(8'h5a);
            pulse_frame();
            check32("move count after pour", active_move_count, 32'd1);

            send_scan_and_wait(8'h3c); // U
            cursor_model = source_index;
            pulse_frame();
            check32("undo move count", active_move_count, 32'd0);
            if (active_tubes !== initial_tubes) begin
                errors = errors + 1;
                $display("FAIL: undo did not restore generated board");
            end

            send_scan_and_wait(8'h2d); // R restart same level
            cursor_model = 0;
            pulse_frame();
            if (active_tubes !== initial_tubes) begin
                errors = errors + 1;
                $display("FAIL: restart did not reproduce generated board");
            end
            send_scan_and_wait(8'h3a); // M menu
            pulse_frame();
            check32("return to menu", active_ui & 32'h200, 32'h0);
        end

        if (errors == 0)
            $display("PASS: water sort firmware integration test completed");
        else
            $display("FAIL: water sort firmware integration test completed with %0d error(s)", errors);
        $finish;
    end

    always #5 clk = ~clk;
endmodule
