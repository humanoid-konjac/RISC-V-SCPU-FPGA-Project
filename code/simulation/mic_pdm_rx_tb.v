`timescale 1ns/1ps

module mic_pdm_rx_tb;
    reg clk;
    reg rst;
    reg mic_data;
    wire mic_clk;
    wire mic_lrsel;
    wire signed [15:0] pcm_sample;
    wire [15:0] density;
    wire sample_valid;
    integer errors;

    mic_pdm_rx #(
        .PDM_HALF_DIV(2),
        .DECIMATION(8)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mic_data(mic_data),
        .mic_clk(mic_clk),
        .mic_lrsel(mic_lrsel),
        .pcm_sample(pcm_sample),
        .density(density),
        .sample_valid(sample_valid)
    );

    always #5 clk = ~clk;

    task wait_sample;
        begin
            @(posedge sample_valid);
            #1;
        end
    endtask

    task check16;
        input [127:0] name;
        input [15:0] got;
        input [15:0] expected;
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s got=%0d expected=%0d", name, got, expected);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        mic_data = 1'b0;
        errors = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        if (mic_lrsel !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: mic_lrsel must select rising-edge data");
        end

        mic_data = 1'b1;
        wait_sample();
        wait_sample();
        check16("all-one density", density, 16'd8);
        check16("all-one pcm", pcm_sample, 16'd4);

        mic_data = 1'b0;
        wait_sample();
        wait_sample();
        check16("all-zero density", density, 16'd0);
        check16("all-zero pcm", pcm_sample, 16'hfffc);

        if (errors == 0)
            $display("PASS: microphone PDM receiver test completed");
        else
            $display("FAIL: microphone PDM receiver test completed with %0d errors", errors);
        $finish;
    end
endmodule
