module MIO_BUS(
    input clk,
    input rst,
    input [4:0] BTN,
    input [15:0] SW,
    input [31:0] PC,
    input mem_w,
    input [31:0] Cpu_data2bus,
    input [31:0] addr_bus,
    input [31:0] ram_data_out,
    input [15:0] led_out,
    input [31:0] counter_out,
    input counter0_out,
    input counter1_out,
    input counter2_out,

    output reg [31:0] Cpu_data4bus,
    output reg [31:0] ram_data_in,
    output reg [9:0] ram_addr,
    output reg data_ram_we,
    output reg GPIOf0000000_we,
    output reg GPIOe0000000_we,
    output reg counter_we,
    output reg [31:0] Peripheral_in
);

    wire addr_f;
    wire counter_addr;

    assign addr_f = (addr_bus[31:28] == 4'hf);
    assign counter_addr = addr_f && (addr_bus[3:0] == 4'h4);

    always @(*) begin
        Cpu_data4bus = 32'b0;
        ram_data_in = 32'b0;
        ram_addr = 10'b0;
        data_ram_we = 1'b0;
        GPIOf0000000_we = 1'b0;
        GPIOe0000000_we = 1'b0;
        counter_we = 1'b0;
        Peripheral_in = 32'b0;

        case (addr_bus[31:28])
            4'b1111: begin
                Cpu_data4bus = counter_addr ? counter_out : {14'b0, led_out, 2'b00};
                data_ram_we = 1'b0;
                GPIOf0000000_we = mem_w && !counter_addr;
                counter_we = mem_w && counter_addr;
                Peripheral_in = Cpu_data2bus;
            end
            4'b1110: begin
                GPIOe0000000_we = mem_w;
                Peripheral_in = Cpu_data2bus;
                data_ram_we = 1'b0;
                Cpu_data4bus = {11'b0, BTN, SW};
            end
            default: begin
                Cpu_data4bus = ram_data_out;
                ram_data_in = Cpu_data2bus;
                ram_addr = addr_bus[11:2];
                data_ram_we = mem_w;
            end
        endcase
    end

endmodule
