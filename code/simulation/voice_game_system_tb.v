`timescale 1ns/1ps

module voice_game_system_tb;
    reg clk;
    reg rst;
    reg frame_tick;
    reg inject_mic_event;
    reg mic_event_pending;
    reg [1:0] enable_divider;
    wire cpu_enable = (enable_divider == 2'b00);
    wire [31:0] instruction;
    wire [31:0] pc;
    wire mem_w;
    wire [31:0] address;
    wire [31:0] write_data;
    wire [31:0] read_data;
    wire [2:0] dm_ctrl;
    wire cpu_mio;
    wire [31:0] bus_read_data;
    wire [31:0] peripheral_write_data;
    wire [31:0] mic_read_data;
    wire [31:0] video_read_data;
    wire mic_we;
    wire video_we;
    wire mic_enable;
    wire manual_threshold_enable;
    wire [15:0] threshold_high_config;
    wire [15:0] threshold_low_config;
    wire calibrate_start;
    wire event_clear;
    wire [1:0] game_control;
    wire [9:0] player_y;
    wire [9:0] obstacle_x;
    wire [9:0] gap_y;
    wire [15:0] score;
    wire [1:0] lives;
    wire player_hurt;
    wire [31:0] frame_sequence;
    reg [31:0] imem [0:1023];
    integer errors;
    integer i;
    integer collision_frames;
    reg [9:0] previous_y;

    assign instruction = imem[pc[11:2]];
    assign read_data = (address[31:12] == 20'h00000)
                     ? 32'b0 : bus_read_data;

    SCPU cpu (
        .clk(clk), .reset(rst), .en(cpu_enable), .MIO_ready(1'b1),
        .inst_in(instruction), .Data_in(read_data), .mem_w(mem_w),
        .PC_out(pc), .Addr_out(address), .dm_ctrl(dm_ctrl),
        .Data_out(write_data), .CPU_MIO(cpu_mio), .INT(1'b0)
    );

    MIO_BUS bus (
        .clk(clk), .rst(rst), .BTN(5'b0), .SW(16'b0), .PC(pc),
        .mem_w(mem_w), .Cpu_data2bus(write_data), .addr_bus(address),
        .ram_data_out(32'b0), .led_out(16'b0), .counter_out(32'b0),
        .counter0_out(1'b0), .counter1_out(1'b0), .counter2_out(1'b0),
        .mic_data_out(mic_read_data), .video_data_out(video_read_data),
        .Cpu_data4bus(bus_read_data), .ram_data_in(), .ram_addr(),
        .data_ram_we(), .GPIOf0000000_we(), .GPIOe0000000_we(),
        .counter_we(), .mic_we(mic_we), .video_we(video_we),
        .Peripheral_in(peripheral_write_data)
    );

    mic_mmio mic (
        .clk(clk), .rst(rst), .write_enable(mic_we && cpu_enable),
        .word_address(address[5:2]), .write_data(write_data),
        .pcm_sample(16'sd0), .level(16'd0), .noise_floor(16'd0),
        .threshold_high_effective(16'd8),
        .threshold_low_effective(16'd4), .calibrated(1'b1),
        .above_threshold(1'b0), .event_pending(mic_event_pending),
        .event_sequence(16'd0), .read_data(mic_read_data),
        .enable(mic_enable),
        .manual_threshold_enable(manual_threshold_enable),
        .threshold_high_config(threshold_high_config),
        .threshold_low_config(threshold_low_config),
        .calibrate_start(calibrate_start), .event_clear(event_clear)
    );

    video_mmio video (
        .clk(clk), .rst(rst), .frame_tick(frame_tick),
        .write_enable(video_we && cpu_enable), .word_address(address[5:2]),
        .write_data(write_data), .read_data(video_read_data),
        .game_control(game_control), .player_y(player_y),
        .obstacle_x(obstacle_x), .gap_y(gap_y), .score(score),
        .lives(lives), .player_hurt(player_hurt),
        .frame_sequence(frame_sequence)
    );

    always #5 clk = ~clk;

    always @(posedge clk or posedge rst) begin
        if (rst)
            enable_divider <= 2'b00;
        else
            enable_divider <= enable_divider + 2'd1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            mic_event_pending <= 1'b0;
        else begin
            if (event_clear)
                mic_event_pending <= 1'b0;
            if (inject_mic_event)
                mic_event_pending <= 1'b1;
        end
    end

    task wait_cycles;
        input integer count;
        begin
            for (i = 0; i < count; i = i + 1)
                @(posedge clk);
        end
    endtask

    task next_frame;
        begin
            @(negedge clk);
            frame_tick = 1'b1;
            @(negedge clk);
            frame_tick = 1'b0;
            wait_cycles(720);
        end
    endtask

    task trigger_sound;
        begin
            @(negedge clk);
            inject_mic_event = 1'b1;
            @(negedge clk);
            inject_mic_event = 1'b0;
        end
    endtask

    initial begin
        $readmemh("software/voice_game.hex", imem);
        clk = 1'b0;
        rst = 1'b1;
        frame_tick = 1'b0;
        inject_mic_event = 1'b0;
        enable_divider = 2'b0;
        errors = 0;

        wait_cycles(5);
        rst = 1'b0;
        wait_cycles(640);

        if (game_control !== 2'b11 || player_y !== 10'd224 ||
            lives !== 2'd3) begin
            errors = errors + 1;
            $display("FAIL: firmware did not initialize the waiting screen");
        end

        trigger_sound();
        next_frame();
        if (game_control !== 2'b01 || player_y !== 10'd224 ||
            mic_event_pending !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: sound event did not start game and clear MIC_STATUS");
        end

        next_frame();
        if (player_y !== 10'd225 || obstacle_x !== 10'd618) begin
            errors = errors + 1;
            $display("FAIL: first physics frame y=%0d obstacle=%0d",
                     player_y, obstacle_x);
        end

        previous_y = player_y;
        trigger_sound();
        next_frame();
        if (player_y !== previous_y - 10'd9) begin
            errors = errors + 1;
            $display("FAIL: strong flap y=%0d expected=%0d",
                     player_y, previous_y - 10'd9);
        end

        collision_frames = 0;
        while ((lives == 2'd3) && (collision_frames < 100)) begin
            next_frame();
            collision_frames = collision_frames + 1;
        end
        if ((lives !== 2'd2) || (game_control !== 2'b01) ||
            !player_hurt) begin
            errors = errors + 1;
            $display("FAIL: relaxed collision lives=%0d control=%b hurt=%b y=%0d obstacle=%0d frames=%0d",
                     lives, game_control, player_hurt, player_y, obstacle_x,
                     frame_sequence);
        end

        repeat (10)
            next_frame();
        if (lives !== 2'd2) begin
            errors = errors + 1;
            $display("FAIL: invulnerability did not protect remaining lives");
        end

        collision_frames = 0;
        while ((lives == 2'd2) && (collision_frames < 140)) begin
            next_frame();
            collision_frames = collision_frames + 1;
        end
        if ((lives !== 2'd1) || (game_control !== 2'b01)) begin
            errors = errors + 1;
            $display("FAIL: second collision lives=%0d control=%b",
                     lives, game_control);
        end

        collision_frames = 0;
        while ((lives == 2'd1) && (collision_frames < 140)) begin
            next_frame();
            collision_frames = collision_frames + 1;
        end
        if ((lives !== 2'd0) || (game_control !== 2'b11)) begin
            errors = errors + 1;
            $display("FAIL: third collision did not enter game over");
        end

        trigger_sound();
        next_frame();
        if ((lives !== 2'd3) || (game_control !== 2'b01) ||
            (player_y !== 10'd224)) begin
            errors = errors + 1;
            $display("FAIL: restart did not restore relaxed game state");
        end

        if (errors == 0)
            $display("PASS: RV32I voice game system test completed");
        else
            $display("FAIL: RV32I voice game system test completed with %0d errors", errors);
        $finish;
    end
endmodule
