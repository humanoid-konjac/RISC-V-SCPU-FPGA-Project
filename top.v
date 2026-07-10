`timescale 1ns / 1ps

module top(
    input         clk,
    input         rstn,
    input  [4:0] btn_i,
    input [15:0] sw_i,
    input         ps2_clk,
    input         ps2_data,
    input         mic_data,
    output        mic_clk,
    output        mic_lrsel,
    output [15:0] led_o,
    output  [7:0] disp_an_o,
    output  [7:0] disp_seg_o,
    output  [3:0] vga_r,
    output  [3:0] vga_g,
    output  [3:0] vga_b,
    output        vga_hs,
    output        vga_vs
);

    wire rst_i;
    wire IO_clk_i;
    wire clka0_i;
    wire Clk_CPU;
    wire cpu_en;
    reg  Clk_CPU_d;

    wire  [4:0] BTN_OK;
    wire [15:0] SW_OK;
    wire [31:0] clkdiv;

    wire [31:0] PC;
    wire [31:0] inst_in;
    wire [31:0] Addr_out;
    wire [31:0] Data_out;
    wire [31:0] Data_in;
    wire [31:0] Cpu_data4bus;
    wire [31:0] Peripheral_in;
    wire [31:0] CPU2IO;

    wire        mem_w;
    wire        CPU_MIO;
    wire  [2:0] dm_ctrl;

    wire [31:0] mio_ram_data_in;
    wire  [9:0] mio_ram_addr;
    wire [31:0] douta;
    wire [31:0] dina;
    wire  [3:0] wea_mem;
    wire  [3:0] wea_mem_raw;
    wire        mio_data_ram_we;
    wire        ram_access;
    wire [31:0] Data_in_dm;

    wire [15:0] LED_out;
    wire        GPIOf0000000_we;
    wire        GPIOe0000000_we;
    wire [13:0] GPIOf0_unused;

    wire        counter_we;
    wire  [1:0] counter_set;
    wire [31:0] counter_out;
    wire        counter0_OUT;
    wire        counter1_OUT;
    wire        counter2_OUT;

    wire [31:0] mic_read_data;
    wire [31:0] video_read_data;
    wire        mio_mic_we;
    wire        mio_video_we;
    wire        mic_write_pulse;
    wire        video_write_pulse;
    wire signed [15:0] mic_pcm_sample;
    wire [15:0] mic_density;
    wire        mic_sample_valid;
    wire [15:0] mic_level;
    wire [15:0] mic_noise_floor;
    wire [15:0] mic_threshold_high_effective;
    wire [15:0] mic_threshold_low_effective;
    wire        mic_calibrated;
    wire        mic_above_threshold;
    wire        mic_event_pulse;
    wire        mic_event_pending;
    wire [15:0] mic_event_sequence;
    wire        mic_enable;
    wire        mic_manual_threshold_enable;
    wire [15:0] mic_threshold_high_config;
    wire [15:0] mic_threshold_low_config;
    wire        mic_calibrate_start;
    wire        mic_event_clear;
    reg         btn_center_d;
    wire        mic_manual_trigger;

    wire [1:0]  game_control;
    wire [9:0]  game_player_y;
    wire [9:0]  game_obstacle_x;
    wire [9:0]  game_gap_y;
    wire [15:0] game_score;
    wire  [1:0] game_lives;
    wire        game_player_hurt;
    wire [31:0] game_frame_sequence;

    wire [31:0] Disp_num;
    wire  [7:0] point_out;
    wire  [7:0] LE_out;
    wire [31:0] keyboard_hex;
    wire  [7:0] ps2_scan_code;
    wire        ps2_scan_valid;
    wire [31:0] display_hex;
    wire [31:0] mic_display_hex;
    wire        vga_pixel_tick;
    wire  [9:0] vga_pixel_x;
    wire  [9:0] vga_pixel_y;
    wire        vga_active_video;
    wire        vga_frame_tick;
    wire        move_up;
    wire        move_down;
    wire        move_left;
    wire        move_right;
    wire        keyboard_jump;
    wire  [9:0] vga_sprite_x_unused;
    wire  [9:0] vga_sprite_y_unused;
    wire  [3:0] vga_test_r;
    wire  [3:0] vga_test_g;
    wire  [3:0] vga_test_b;
    wire  [3:0] vga_game_r;
    wire  [3:0] vga_game_g;
    wire  [3:0] vga_game_b;

    assign rst_i = ~rstn;
    assign IO_clk_i = ~clk;
    assign clka0_i = ~clk;
    assign CPU2IO = Peripheral_in;
    assign ram_access = (Addr_out[31:12] == 20'h00000);
    assign wea_mem = ram_access ? wea_mem_raw : 4'b0000;
    assign Data_in = ram_access ? Data_in_dm : Cpu_data4bus;
    assign cpu_en = Clk_CPU && !Clk_CPU_d;
    assign mic_write_pulse = mio_mic_we && cpu_en;
    assign video_write_pulse = mio_video_we && cpu_en;
    assign mic_manual_trigger = (BTN_OK[0] && !btn_center_d) || keyboard_jump;
    assign mic_display_hex = {8'ha0, mic_calibrated, mic_event_pending,
                              6'b0, mic_level};
    assign display_hex = SW_OK[15] ? keyboard_hex :
                         (SW_OK[12] ? mic_display_hex : Disp_num);
    assign vga_r = SW_OK[13] ? vga_game_r : vga_test_r;
    assign vga_g = SW_OK[13] ? vga_game_g : vga_test_g;
    assign vga_b = SW_OK[13] ? vga_game_b : vga_test_b;

    always @(posedge clk or posedge rst_i) begin
        if (rst_i)
            Clk_CPU_d <= 1'b0;
        else
            Clk_CPU_d <= Clk_CPU;
    end

    always @(posedge clk or posedge rst_i) begin
        if (rst_i)
            btn_center_d <= 1'b0;
        else
            btn_center_d <= BTN_OK[0];
    end

    Enter U10_Enter(
        .clk(clk),
        .BTN(btn_i),
        .SW(sw_i),
        .BTN_out(BTN_OK),
        .SW_out(SW_OK)
    );

    clk_div U8_clk_div(
        .clk(clk),
        .rst(rst_i),
        .SW2(SW_OK[2]),
        .clkdiv(clkdiv),
        .Clk_CPU(Clk_CPU)
    );

    SCPU U1_SCPU(
        .clk(clk),
        .reset(rst_i),
        .en(cpu_en),
        .MIO_ready(CPU_MIO),
        .inst_in(inst_in),
        .Data_in(Data_in),
        .mem_w(mem_w),
        .PC_out(PC),
        .Addr_out(Addr_out),
        .Data_out(Data_out),
        .dm_ctrl(dm_ctrl),
        .CPU_MIO(CPU_MIO),
        .INT(counter0_OUT)
    );

    ROM_D U2_ROMD(
        .a(PC[11:2]),
        .spo(inst_in)
    );

    dm_controller U3_dm_controller(
        .mem_w(mem_w),
        .Addr_in(Addr_out),
        .Data_write(Data_out),
        .dm_ctrl(dm_ctrl),
        .Data_read_from_dm(douta),
        .Data_read(Data_in_dm),
        .Data_write_to_dm(dina),
        .wea_mem(wea_mem_raw)
    );

    RAM_B U3_RAM_B(
        .addra(Addr_out[11:2]),
        .clka(clka0_i),
        .dina(dina),
        .wea(wea_mem),
        .douta(douta)
    );

    MIO_BUS U4_MIO_BUS(
        .clk(clk),
        .rst(rst_i),
        .BTN(BTN_OK),
        .SW(SW_OK),
        .PC(PC),
        .mem_w(mem_w),
        .Cpu_data2bus(Data_out),
        .addr_bus(Addr_out),
        .ram_data_out(32'b0),
        .led_out(LED_out),
        .counter_out(counter_out),
        .counter0_out(counter0_OUT),
        .counter1_out(counter1_OUT),
        .counter2_out(counter2_OUT),
        .mic_data_out(mic_read_data),
        .video_data_out(video_read_data),
        .Cpu_data4bus(Cpu_data4bus),
        .ram_data_in(mio_ram_data_in),
        .ram_addr(mio_ram_addr),
        .data_ram_we(mio_data_ram_we),
        .GPIOf0000000_we(GPIOf0000000_we),
        .GPIOe0000000_we(GPIOe0000000_we),
        .counter_we(counter_we),
        .mic_we(mio_mic_we),
        .video_we(mio_video_we),
        .Peripheral_in(Peripheral_in)
    );

    mic_pdm_rx U16_mic_pdm_rx(
        .clk(clk),
        .rst(rst_i),
        .mic_data(mic_data),
        .mic_clk(mic_clk),
        .mic_lrsel(mic_lrsel),
        .pcm_sample(mic_pcm_sample),
        .density(mic_density),
        .sample_valid(mic_sample_valid)
    );

    mic_voice_trigger U17_mic_voice_trigger(
        .clk(clk),
        .rst(rst_i),
        .enable(mic_enable),
        .calibrate_start(mic_calibrate_start),
        .event_clear(mic_event_clear),
        .manual_trigger(mic_manual_trigger),
        .sensitive_mode(SW_OK[11]),
        .manual_threshold_enable(mic_manual_threshold_enable),
        .threshold_high_config(mic_threshold_high_config),
        .threshold_low_config(mic_threshold_low_config),
        .pcm_sample(mic_pcm_sample),
        .sample_valid(mic_sample_valid),
        .level(mic_level),
        .noise_floor(mic_noise_floor),
        .threshold_high_effective(mic_threshold_high_effective),
        .threshold_low_effective(mic_threshold_low_effective),
        .calibrated(mic_calibrated),
        .above_threshold(mic_above_threshold),
        .event_pulse(mic_event_pulse),
        .event_pending(mic_event_pending),
        .event_sequence(mic_event_sequence)
    );

    mic_mmio U18_mic_mmio(
        .clk(clk),
        .rst(rst_i),
        .write_enable(mic_write_pulse),
        .word_address(Addr_out[5:2]),
        .write_data(Data_out),
        .pcm_sample(mic_pcm_sample),
        .level(mic_level),
        .noise_floor(mic_noise_floor),
        .threshold_high_effective(mic_threshold_high_effective),
        .threshold_low_effective(mic_threshold_low_effective),
        .calibrated(mic_calibrated),
        .above_threshold(mic_above_threshold),
        .event_pending(mic_event_pending),
        .event_sequence(mic_event_sequence),
        .read_data(mic_read_data),
        .enable(mic_enable),
        .manual_threshold_enable(mic_manual_threshold_enable),
        .threshold_high_config(mic_threshold_high_config),
        .threshold_low_config(mic_threshold_low_config),
        .calibrate_start(mic_calibrate_start),
        .event_clear(mic_event_clear)
    );

    video_mmio U19_video_mmio(
        .clk(clk),
        .rst(rst_i),
        .frame_tick(vga_frame_tick),
        .write_enable(video_write_pulse),
        .word_address(Addr_out[5:2]),
        .write_data(Data_out),
        .read_data(video_read_data),
        .game_control(game_control),
        .player_y(game_player_y),
        .obstacle_x(game_obstacle_x),
        .gap_y(game_gap_y),
        .score(game_score),
        .lives(game_lives),
        .player_hurt(game_player_hurt),
        .frame_sequence(game_frame_sequence)
    );

    Multi_8CH32 U5_Multi_8CH32(
        .clk(IO_clk_i),
        .rst(rst_i),
        .EN(GPIOe0000000_we),
        .Switch(SW_OK[7:5]),
        .point_in({clkdiv, clkdiv}),
        .LES(64'hffff_ffff_ffff_ffff),
        .data0(CPU2IO),
        .data1({2'b00, PC[31:2]}),
        .data2(inst_in),
        .data3(counter_out),
        .data4(Addr_out),
        .data5(Data_out),
        .data6(Cpu_data4bus),
        .data7(PC),
        .point_out(point_out),
        .LE_out(LE_out),
        .Disp_num(Disp_num)
    );

    ps2_keyboard U11_ps2_keyboard(
        .clk(clk),
        .rst(rst_i),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .scan_code(ps2_scan_code),
        .scan_valid(ps2_scan_valid)
    );

    keyboard_display U12_keyboard_display(
        .clk(clk),
        .rst(rst_i),
        .scan_code(ps2_scan_code),
        .scan_valid(ps2_scan_valid),
        .display_hex(keyboard_hex),
        .last_scan_code(),
        .last_ascii_code(),
        .key_event()
    );

    keyboard_control U13_keyboard_control(
        .clk(clk),
        .rst(rst_i),
        .scan_code(ps2_scan_code),
        .scan_valid(ps2_scan_valid),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
        .jump(keyboard_jump)
    );

    vga_timing U14_vga_timing(
        .clk(clk),
        .rst(rst_i),
        .pixel_tick(vga_pixel_tick),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .active_video(vga_active_video),
        .frame_tick(vga_frame_tick),
        .hsync(vga_hs),
        .vsync(vga_vs)
    );

    vga_test_pattern U15_vga_test_pattern(
        .clk(clk),
        .rst(rst_i),
        .pixel_tick(vga_pixel_tick),
        .active_video(vga_active_video),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .enable_sprite(SW_OK[14]),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
        .vga_r(vga_test_r),
        .vga_g(vga_test_g),
        .vga_b(vga_test_b),
        .sprite_x(vga_sprite_x_unused),
        .sprite_y(vga_sprite_y_unused)
    );

    vga_game_renderer U20_vga_game_renderer(
        .rst(rst_i),
        .active_video(vga_active_video),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .game_control(game_control),
        .player_y(game_player_y),
        .obstacle_x(game_obstacle_x),
        .gap_y(game_gap_y),
        .score(game_score),
        .lives(game_lives),
        .player_hurt(game_player_hurt),
        .frame_sequence(game_frame_sequence),
        .mic_level(mic_level),
        .mic_calibrated(mic_calibrated),
        .mic_event_pending(mic_event_pending),
        .vga_r(vga_game_r),
        .vga_g(vga_game_g),
        .vga_b(vga_game_b)
    );

    SSeg7 U6_SSeg7(
        .clk(clk),
        .rst(rst_i),
        .SW0(SW_OK[0]),
        .flash(clkdiv[10]),
        .Hexs(display_hex),
        .point(point_out),
        .LES(LE_out),
        .seg_an(disp_an_o),
        .seg_sout(disp_seg_o)
    );

    SPIO U7_SPIO(
        .clk(IO_clk_i),
        .rst(rst_i),
        .EN(GPIOf0000000_we),
        .P_Data(Peripheral_in),
        .counter_set(counter_set),
        .LED_out(LED_out),
        .led(led_o),
        .GPIOf0(GPIOf0_unused)
    );

    Counter_x U9_Counter_x(
        .clk(IO_clk_i),
        .rst(rst_i),
        .clk0(clkdiv[6]),
        .clk1(clkdiv[9]),
        .clk2(clkdiv[11]),
        .counter_we(counter_we),
        .counter_val(Peripheral_in),
        .counter_ch(counter_set),
        .counter0_OUT(counter0_OUT),
        .counter1_OUT(counter1_OUT),
        .counter2_OUT(counter2_OUT),
        .counter_out(counter_out)
    );

endmodule
