`timescale 1ns / 1ps

module top(
    input         clk,
    input         rstn,
    input  [4:0] btn_i,
    input [15:0] sw_i,
    input         ps2_clk,
    input         ps2_data,
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
    wire        game_access;
    wire        game_write_en;
    wire [31:0] Data_in_dm;
    wire [31:0] keyboard_mmio_data;
    wire [31:0] game_state_mmio_data;
    wire [31:0] game_mmio_data;
    wire        game_key_ready;
    wire  [7:0] game_key_code;
    wire [255:0] game_active_tubes;
    wire [31:0] game_active_ui;
    wire [31:0] game_active_move_count;

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

    wire [31:0] Disp_num;
    wire  [7:0] point_out;
    wire  [7:0] LE_out;
    wire [31:0] keyboard_hex;
    wire  [7:0] ps2_scan_code;
    wire        ps2_scan_valid;
    wire [31:0] display_hex;
    wire        vga_pixel_tick;
    wire  [9:0] vga_pixel_x;
    wire  [9:0] vga_pixel_y;
    wire        vga_active_video;
    wire        vga_frame_tick;
    wire        move_up;
    wire        move_down;
    wire        move_left;
    wire        move_right;
    wire  [9:0] vga_sprite_x_unused;
    wire  [9:0] vga_sprite_y_unused;
    wire  [3:0] test_vga_r;
    wire  [3:0] test_vga_g;
    wire  [3:0] test_vga_b;
    wire  [3:0] game_vga_r;
    wire  [3:0] game_vga_g;
    wire  [3:0] game_vga_b;
    wire [11:0] selected_vga_rgb;
    wire        vga_hs_raw;
    wire        vga_vs_raw;

    assign rst_i = ~rstn;
    assign IO_clk_i = ~clk;
    assign clka0_i = ~clk;
    assign CPU2IO = Peripheral_in;
    assign ram_access = (Addr_out[31:12] == 20'h00000) ||
                        (Addr_out[31:12] == 20'h10000);
    assign game_access = (Addr_out[31:12] == 20'hd0000);
    assign game_write_en = cpu_en && mem_w && game_access;
    assign game_mmio_data = keyboard_mmio_data | game_state_mmio_data;
    assign wea_mem = ram_access ? wea_mem_raw : 4'b0000;
    assign Data_in = ram_access ? Data_in_dm :
                     (game_access ? game_mmio_data : Cpu_data4bus);
    assign cpu_en = Clk_CPU && !Clk_CPU_d;
    assign display_hex = SW_OK[15] ? keyboard_hex : Disp_num;
    assign selected_vga_rgb = SW_OK[14] ?
                              {game_vga_r, game_vga_g, game_vga_b} :
                              {test_vga_r, test_vga_g, test_vga_b};

    always @(posedge clk or posedge rst_i) begin
        if (rst_i)
            Clk_CPU_d <= 1'b0;
        else
            Clk_CPU_d <= Clk_CPU;
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
        .Cpu_data4bus(Cpu_data4bus),
        .ram_data_in(mio_ram_data_in),
        .ram_addr(mio_ram_addr),
        .data_ram_we(mio_data_ram_we),
        .GPIOf0000000_we(GPIOf0000000_we),
        .GPIOe0000000_we(GPIOe0000000_we),
        .counter_we(counter_we),
        .Peripheral_in(Peripheral_in)
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
        .move_right(move_right)
    );

    keyboard_event_mmio U16_keyboard_event_mmio(
        .clk(clk),
        .rst(rst_i),
        .scan_code(ps2_scan_code),
        .scan_valid(ps2_scan_valid),
        .write_en(game_write_en),
        .addr(Addr_out),
        .write_data(Data_out),
        .read_data(keyboard_mmio_data),
        .key_ready(game_key_ready),
        .key_code(game_key_code)
    );

    game_state_mmio U17_game_state_mmio(
        .clk(clk),
        .rst(rst_i),
        .write_en(game_write_en),
        .addr(Addr_out),
        .write_data(Data_out),
        .frame_tick(vga_frame_tick),
        .read_data(game_state_mmio_data),
        .active_tubes(game_active_tubes),
        .active_ui(game_active_ui),
        .active_move_count(game_active_move_count)
    );

    vga_timing U14_vga_timing(
        .clk(clk),
        .rst(rst_i),
        .pixel_tick(vga_pixel_tick),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .active_video(vga_active_video),
        .frame_tick(vga_frame_tick),
        .hsync(vga_hs_raw),
        .vsync(vga_vs_raw)
    );

    vga_test_pattern U15_vga_test_pattern(
        .clk(clk),
        .rst(rst_i),
        .pixel_tick(vga_pixel_tick),
        .active_video(vga_active_video),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .enable_sprite(1'b1),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
        .vga_r(test_vga_r),
        .vga_g(test_vga_g),
        .vga_b(test_vga_b),
        .sprite_x(vga_sprite_x_unused),
        .sprite_y(vga_sprite_y_unused)
    );

    vga_game_pattern U18_vga_game_pattern(
        .clk(clk),
        .rst(rst_i),
        .frame_tick(vga_frame_tick),
        .active_video(vga_active_video),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .active_tubes(game_active_tubes),
        .active_ui(game_active_ui),
        .vga_r(game_vga_r),
        .vga_g(game_vga_g),
        .vga_b(game_vga_b)
    );

    vga_output_register U19_vga_output_register(
        .clk(clk),
        .rst(rst_i),
        .rgb_in(selected_vga_rgb),
        .hsync_in(vga_hs_raw),
        .vsync_in(vga_vs_raw),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync_out(vga_hs),
        .vsync_out(vga_vs)
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
