`timescale 1ns/1ps

module game_state_mmio_tb;
    reg clk;
    reg rst;
    reg write_en;
    reg [31:0] addr;
    reg [31:0] write_data;
    reg frame_tick;
    wire [31:0] read_data;
    wire [255:0] active_tubes;
    wire [31:0] active_ui;
    wire [31:0] active_move_count;
    wire [31:0] active_meta;
    wire [31:0] active_level;
    integer errors;

    game_state_mmio U_DUT(
        .clk(clk),
        .rst(rst),
        .write_en(write_en),
        .addr(addr),
        .write_data(write_data),
        .frame_tick(frame_tick),
        .read_data(read_data),
        .active_tubes(active_tubes),
        .active_ui(active_ui),
        .active_move_count(active_move_count),
        .active_meta(active_meta),
        .active_level(active_level)
    );

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

    task write_reg;
        input [31:0] write_addr;
        input [31:0] value;
        begin
            @(negedge clk);
            addr = write_addr;
            write_data = value;
            write_en = 1'b1;
            @(posedge clk);
            #1 write_en = 1'b0;
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

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        write_en = 1'b0;
        addr = 32'b0;
        write_data = 32'b0;
        frame_tick = 1'b0;
        errors = 0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        write_reg(32'hd0000020, 32'h00002121);
        write_reg(32'hd0000040, 32'h00000180);
        write_reg(32'hd0000044, 32'h00000007);
        write_reg(32'hd000004c, 32'h00210082);
        write_reg(32'hd0000050, 32'h00000012);
        write_reg(32'hd0000048, 32'h00000001);

        check32("active waits for frame", active_tubes[31:0], 32'h0);
        write_reg(32'hd0000020, 32'h00000002);
        addr = 32'hd0000020;
        #1 check32("shadow readable", read_data, 32'h2);

        pulse_frame();
        check32("committed snapshot tube", active_tubes[31:0], 32'h00002121);
        check32("committed snapshot UI", active_ui, 32'h00000180);
        check32("committed snapshot moves", active_move_count, 32'h7);
        check32("committed metadata", active_meta, 32'h00210082);
        check32("committed level", active_level, 32'h12);

        // The post-COMMIT shadow write did not alter the pending snapshot.
        write_reg(32'hd0000048, 32'h1);
        check32("second commit still waits", active_tubes[31:0], 32'h00002121);
        pulse_frame();
        check32("second frame updates active", active_tubes[31:0], 32'h2);

        if (errors == 0)
            $display("PASS: game state MMIO test completed");
        else
            $display("FAIL: game state MMIO test completed with %0d error(s)", errors);
        $finish;
    end

    always #5 clk = ~clk;
endmodule
