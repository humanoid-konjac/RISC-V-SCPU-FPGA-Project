`timescale 1ns/1ps

module keyboard_event_mmio_tb;
    reg clk;
    reg rst;
    reg [7:0] scan_code;
    reg scan_valid;
    reg write_en;
    reg [31:0] addr;
    reg [31:0] write_data;
    wire [31:0] read_data;
    wire key_ready;
    wire [7:0] key_code;
    integer errors;

    keyboard_event_mmio U_DUT(
        .clk(clk),
        .rst(rst),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .write_en(write_en),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .key_ready(key_ready),
        .key_code(key_code)
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

    task send_scan;
        input [7:0] value;
        begin
            @(negedge clk);
            scan_code = value;
            scan_valid = 1'b1;
            @(posedge clk);
            #1 scan_valid = 1'b0;
        end
    endtask

    task ack_event;
        begin
            @(negedge clk);
            addr = 32'hd0000008;
            write_data = 32'h1;
            write_en = 1'b1;
            @(posedge clk);
            #1 write_en = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        scan_code = 8'b0;
        scan_valid = 1'b0;
        write_en = 1'b0;
        addr = 32'hd0000000;
        write_data = 32'b0;
        errors = 0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        send_scan(8'h1c); // A make
        addr = 32'hd0000000;
        #1 check32("A ready", read_data, 32'h1);
        addr = 32'hd0000004;
        #1 check32("A code", read_data, 32'h1);

        send_scan(8'h23); // D is dropped while A remains pending
        check32("pending event preserved", {24'b0, key_code}, 32'h1);
        ack_event();
        check32("ack clears ready", {31'b0, key_ready}, 32'h0);

        send_scan(8'he0);
        send_scan(8'h74); // right arrow make
        check32("right arrow code", {24'b0, key_code}, 32'h2);
        ack_event();

        send_scan(8'he0);
        send_scan(8'hf0);
        send_scan(8'h74); // right arrow break
        check32("break ignored", {31'b0, key_ready}, 32'h0);

        send_scan(8'h5a); // Enter
        check32("enter code", {24'b0, key_code}, 32'h3);
        ack_event();
        send_scan(8'h76); // Esc
        check32("escape code", {24'b0, key_code}, 32'h4);
        ack_event();

        // A new event arriving with ACK wins over clearing the old event.
        send_scan(8'h1c);
        @(negedge clk);
        addr = 32'hd0000008;
        write_data = 32'h1;
        write_en = 1'b1;
        scan_code = 8'h2d;
        scan_valid = 1'b1;
        @(posedge clk);
        #1 begin
            write_en = 1'b0;
            scan_valid = 1'b0;
        end
        check32("ack/new event race", {24'b0, key_code}, 32'h5);
        check32("ack/new ready", {31'b0, key_ready}, 32'h1);
        ack_event();

        send_scan(8'h3c); // U
        check32("undo code", {24'b0, key_code}, 32'h6);
        ack_event();
        send_scan(8'h3a); // M
        check32("menu code", {24'b0, key_code}, 32'h7);
        ack_event();
        send_scan(8'h66); // Backspace
        check32("backspace code", {24'b0, key_code}, 32'h8);
        ack_event();
        send_scan(8'h45); // 0
        check32("digit zero code", {24'b0, key_code}, 32'h10);
        ack_event();
        send_scan(8'h46); // 9
        check32("digit nine code", {24'b0, key_code}, 32'h19);
        ack_event();

        addr = 32'hd000000c;
        #1 write_data = read_data;
        repeat (2) @(posedge clk);
        if (read_data === write_data) begin
            errors = errors + 1;
            $display("FAIL: free-running random counter did not advance");
        end

        if (errors == 0)
            $display("PASS: keyboard event MMIO test completed");
        else
            $display("FAIL: keyboard event MMIO test completed with %0d error(s)", errors);
        $finish;
    end

    always #5 clk = ~clk;
endmodule
