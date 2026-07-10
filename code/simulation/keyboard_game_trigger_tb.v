`timescale 1ns/1ps

module keyboard_game_trigger_tb;
    reg clk;
    reg rst;
    reg [7:0] scan_code;
    reg scan_valid;
    wire move_up;
    wire move_down;
    wire move_left;
    wire move_right;
    wire jump;
    wire event_pending;
    wire [15:0] event_sequence;
    integer errors;

    keyboard_control keyboard (
        .clk(clk),
        .rst(rst),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
        .jump(jump)
    );

    mic_voice_trigger trigger (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .calibrate_start(1'b0),
        .event_clear(1'b0),
        .manual_trigger(jump),
        .sensitive_mode(1'b0),
        .manual_threshold_enable(1'b0),
        .threshold_high_config(16'd16),
        .threshold_low_config(16'd8),
        .pcm_sample(16'sd0),
        .sample_valid(1'b0),
        .level(),
        .noise_floor(),
        .threshold_high_effective(),
        .threshold_low_effective(),
        .calibrated(),
        .above_threshold(),
        .event_pulse(),
        .event_pending(event_pending),
        .event_sequence(event_sequence)
    );

    always #5 clk = ~clk;

    task send_scan;
        input [7:0] code;
        begin
            @(negedge clk);
            scan_code = code;
            scan_valid = 1'b1;
            @(negedge clk);
            scan_valid = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task expect_sequence;
        input [15:0] expected;
        input [255:0] name;
        begin
            if (!event_pending || event_sequence !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s pending=%b sequence=%0d expected=%0d",
                         name, event_pending, event_sequence, expected);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        scan_code = 8'b0;
        scan_valid = 1'b0;
        errors = 0;

        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        send_scan(8'h1d); // W make
        expect_sequence(16'd1, "W creates game event");
        send_scan(8'h1d); // W typematic make
        expect_sequence(16'd1, "W typematic is suppressed");
        send_scan(8'hf0);
        send_scan(8'h1d); // W break
        expect_sequence(16'd1, "W break creates no event");
        send_scan(8'h1d); // W pressed again
        expect_sequence(16'd2, "W retriggers after release");

        send_scan(8'he0);
        send_scan(8'h75); // Up arrow make
        expect_sequence(16'd3, "up arrow creates game event");

        send_scan(8'h29); // Space make
        expect_sequence(16'd4, "space creates game event");

        if (errors == 0)
            $display("PASS: keyboard game trigger test completed");
        else
            $display("FAIL: keyboard game trigger test completed with %0d errors",
                     errors);
        $finish;
    end
endmodule
