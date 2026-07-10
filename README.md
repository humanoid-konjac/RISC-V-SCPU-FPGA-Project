# RISC-V SCPU FPGA Project

这是一个用于 Vivado 下板的五级流水线 RISC-V CPU 工程。当前版本使用自写 `SCPU` 和 `dm_controller`，保留了参考工程中可用的 IO/显示/总线模块。

## 目录结构

- `top.v`: FPGA 顶层，连接 CPU、ROM、RAM、外设总线、数码管、LED、按键、开关、PS/2 键盘和 VGA。
- `code/`: 自写 CPU RTL，包括五级流水线 CPU、控制器、ALU、寄存器堆、立即数扩展、访存控制等。
- `IO/`: 板级 IO RTL，包括按键/开关输入处理、分频器、计数器、PS/2 键盘接收和 VGA 测试显示。
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

## VGA 显示测试

`top.v` 提供 VGA 直连测试输出，用于先验证显示器物理链路和键盘到画面的反馈：

- 输出端口为 `vga_r[3:0]`、`vga_g[3:0]`、`vga_b[3:0]`、`vga_hs`、`vga_vs`。
- 当前实现为纯 RTL `640x480@60Hz` 测试图，不经过 CPU、RAM 或 `MIO_BUS`。
- 画面包含色条、白色边框和中心参考线，便于检查颜色顺序、同步和可视区域。
- `SW14 = 1` 时叠加键盘控制方块，方向键或 WASD 可移动方块；`SW14 = 0` 时只显示固定测试图。
- `SW15` 仍只控制数码管是否显示键盘值，不影响 VGA。

VGA 管脚按 Digilent Nexys A7-100T master XDC 记录，兼容当前 Nexys4 A7-100T：

```text
vga_r[0..3] -> A3 B4 C5 A4
vga_g[0..3] -> C6 A5 B6 A6
vga_b[0..3] -> B7 C7 D7 D8
vga_hs      -> B11
vga_vs      -> B12
```

该测试已在 NEXYS4 A7-100T 上板通过：`SW14 = 0` 时显示器稳定显示色条和参考线，`SW14 = 1` 时方向键/WASD 可移动方块。

后续 C 语言小游戏显示建议在这条稳定 VGA 输出链路上扩展 tile/framebuffer/MMIO，不要先把完整显存设计和 VGA 物理调试混在一起。

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

## Vivado 导入与上板

在已有 Vivado 工程中，保留现有 `ROM_D`、`RAM_B` IP，执行 **Add Sources -> Add or Create Design Sources**，补齐下列文件；若文件已经存在于工程中，不要重复添加。

1. 顶层：`top.v`，并在 **Settings -> General -> Top module name** 设为 `top`。
2. CPU RTL：`code/SCPU.v`、`code/RF.v`、`code/ctrl.v`、`code/ctrl_encode_def.v`、`code/alu.v`、`code/EXT.v`、`code/dm_controller.v`。
3. 板级 IO：`IO/Counter_3_IO.v`、`IO/Enter.v`、`IO/clk_div.v`、`IO/ps2_keyboard.v`、`IO/keyboard_display.v`、`IO/keyboard_control.v`、`IO/vga_timing.v`、`IO/vga_test_pattern.v`。
4. 参考外设模块：`edf_file/MIO_BUS.V`，以及 `edf_file/Multi_8CH32.v/.edf`、`edf_file/SPIO.v/.edf`、`edf_file/SSeg7.v/.edf`。
5. 约束：在 **Add or Create Constraints** 中只加入当前的 `icf.xdc`，不要保留旧版或重复的 XDC。

以下文件仅用于仿真，不加入 **Design Sources**：`code/simulation/*`、`code/dm.v`、`code/im.v`。`archive/`、`ref/`、`asm2coe/`、`tmp/` 也不加入工程。

`ROM_D` 与 `RAM_B` 是已有 Vivado IP：本次键盘/VGA/中断更新不需要修改或重新生成它们。只有新建空工程或更换 `.coe` 时，才创建/更新 IP：

- `ROM_D`：模块名 `ROM_D`，地址 `a[9:0]`，数据输出 `spo[31:0]`。
- `RAM_B`：模块名 `RAM_B`，地址 `addra[9:0]`，数据 `dina/douta[31:0]`，字节写使能 `wea[3:0]`，时钟 `clka`。

导入完成后依次运行 **Synthesis**、**Implementation**、**Generate Bitstream**。上板时接好 VGA 和 PS/2 键盘，下载 bitstream 后：

- `SW14 = 0`：确认 VGA 色条、白色边框和中心线稳定显示。
- `SW14 = 1`：用方向键或 WASD 移动 VGA 方块。
- `SW15 = 1`：数码管显示最近一次键盘按下值；`SW15 = 0`：恢复原 CPU/IO 数码管显示。

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
