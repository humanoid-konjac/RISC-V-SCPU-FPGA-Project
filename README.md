# RISC-V SCPU FPGA Project

这是一个用于 Vivado 下板的五级流水线 RISC-V CPU 工程。当前版本使用自写 `SCPU` 和 `dm_controller`，保留了参考工程中可用的 IO/显示/总线模块。

## 目录结构

- `top.v`: FPGA 顶层，连接 CPU、ROM、RAM、外设总线、数码管、LED、按键和开关。
- `code/`: 自写 CPU RTL，包括五级流水线 CPU、控制器、ALU、寄存器堆、立即数扩展、访存控制等。
- `IO/`: 板级 IO RTL，包括按键/开关输入处理、分频器、计数器和 PS/2 键盘接收。
- `edf_file/`: 当前仍在工程中使用的参考工程文件，包括 `MIO_BUS`、`Multi_8CH32`、`SSeg7`、`SPIO` 等 IO/显示/总线模块。
- `archive/`: 已从当前工程移出的旧参考文件，仅作备份归档，不参与综合、实现或仿真。归档文件统一使用 `.bak` 后缀，避免 Vivado 递归添加目录时把旧同名模块当作源文件读入。
- `coe/`: Vivado ROM/RAM IP 初始化文件。
- `icf.xdc`: 管脚约束。

`ref/`、`asm2coe/` 和 `tmp/` 是本地参考/辅助内容，不进入 Git。

## 顶层结构

`top.v` 中的主要数据通路：

```text
ROM_D.spo              -> SCPU.inst_in
SCPU.PC_out[11:2]      -> ROM_D.a

SCPU.Addr_out[11:2]    -> RAM_B.addra
SCPU.Data_out          -> dm_controller.Data_write
RAM_B.douta            -> dm_controller.Data_read_from_dm
dm_controller.Data_read -> SCPU.Data_in
dm_controller.wea_mem   -> RAM_B.wea
dm_controller.Data_write_to_dm -> RAM_B.dina
```

普通数据 RAM 访问不经过 `MIO_BUS`。`MIO_BUS` 只负责外设译码、显示相关数据和外设读数据返回；`top.v` 中 `MIO_BUS.ram_data_out` 固定接 `32'b0`，避免把 RAM `douta` 额外扇出到 MIO。

## 键盘显示测试

`top.v` 提供 PS/2 键盘直连数码管测试模式：

- `ps2_clk` 约束到 NEXYS4 A7-100T 的 `F4` 管脚。
- `ps2_data` 约束到 NEXYS4 A7-100T 的 `B2` 管脚。
- `SW15 = 1` 时，数码管显示最近一次按下键的 `{8'h00, ASCII, 8'h00, scan_code}`。
- `SW15 = 0` 时，保持原来的 CPU/IO 数码管显示路径。

该测试已在 NEXYS4 A7-100T 上板通过；后续游戏程序需要键盘输入时，可以复用 `IO/ps2_keyboard.v` 输出的扫描码接入 MMIO 或中断。

## CPU 实现

`SCPU` 是 IF/ID、ID/EX、EX/MEM、MEM/WB 五级流水线实现：

- 数据冒险通过 EX/MEM、MEM/WB 到 EX 阶段的旁路解决。
- WB 到 ID 读寄存器有旁路，保留 `U_RF` 实例名，便于现有仿真层级访问。
- store 写数据使用旁路后的 `rs2` 值。
- 典型 load-use 冒险插入 1 个 bubble。
- 控制冒险使用静态预测：`jal` 预测 taken；条件分支按立即数符号预测，后跳 taken、前跳 not taken；`jalr` 在 EX 阶段重定向；预测错误时 flush IF/ID 和 ID/EX。
- `RF` 在下降沿写回，复位时 `x2` 初始化为 `0x00000400`。

板上时钟结构：

- `SCPU.clk` 使用板载 100MHz `clk`，不直接使用 `clkdiv` 派生时钟。
- `clk_div` 输出的 `Clk_CPU` 只用于在 `top.v` 中生成单周期 `cpu_en`，控制流水线推进速度。
- 修改 `clk_div.v` 中 `Clk_CPU` 的分频位后，`cpu_en` 会自动跟随实际 `Clk_CPU` 上升沿，不需要同步改 `top.v`。
- `RAM_B.clka` 和 IO 写寄存器采样时钟使用 `~clk`，保持 CPU/RAM/IO 时序关系稳定。

## 存储器 IP 要求

指令 ROM：

- 模块名：`ROM_D`
- 地址：`a[9:0]`
- 数据输出：`spo[31:0]`

数据 RAM：

- 模块名：`RAM_B`
- 地址：`addra[9:0]`
- 时钟：`clka` 接 `~clk`
- 写数据：`dina[31:0]`
- 字节写使能：`wea[3:0]`
- 读数据：`douta[31:0]`

切换 `.coe` 后，需要重新生成对应 IP 的 output products，然后重新综合、实现、生成 bitstream。

## Vivado Source Set

Vivado 工程中应只加入当前使用的源码/IP：

- `top.v`
- `code/*.v`
- `IO/*.v`
- `edf_file/MIO_BUS.V`
- `edf_file/Multi_8CH32.v` 和 `edf_file/Multi_8CH32.edf`
- `edf_file/SPIO.v` 和 `edf_file/SPIO.edf`
- `edf_file/SSeg7.v` 和 `edf_file/SSeg7.edf`
- `ROM_D`、`RAM_B` 两个 Vivado IP

不要把 `archive/` 加入 Vivado source set。里面是旧的 `MIO_BUS`、`SCPU`、`dm_controller` 参考实现，只用于备份。

## 版本标记

- `single-cycle-v1`: 合并流水线前的单周期 CPU 版本。
- `pipeline-v1`: 当前通过板上 `testac.coe` 的五级流水线 CPU 版本。

## `dm_controller`

`dm_controller` 处理 CPU 的 load/store 访存格式：

- word：直接读写 32 位。
- halfword：按 `Addr_in[1]` 选择高/低 16 位，并做符号扩展。
- halfword unsigned：按 `Addr_in[1]` 选择高/低 16 位，并做零扩展。
- byte：按 `Addr_in[1:0]` 选择字节，并做符号扩展。
- byte unsigned：按 `Addr_in[1:0]` 选择字节，并做零扩展。

写内存时，`Data_write_to_dm` 负责把待写数据放到正确字节 lane，`wea_mem[3:0]` 负责只写对应字节。
