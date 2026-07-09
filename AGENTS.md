# AGENTS.md

本文件给后续在本目录工作的代码代理使用。回复使用中文。

## 项目结构

- 顶层：`top.v`
- CPU RTL：`code/`
- 板级 IO：`IO/`
- 参考工程模块：`edf_file/`
- COE 文件：`coe/`
- 管脚约束：`icf.xdc`
- 以前的文档归档：`archive/`
- 参考的外部信息：`ref/`
  PS2 接口参考文件和 VGA 接口参考文件在 `ref/` 目录下
- 当前 CPU 状态：五级流水线 `SCPU`

## 背景与当前进度

这是计算机系统综合设计课程的实验项目。

实验要求与实现评分标准：

1. 支持37条指令单周期CPU下板实验并运行测试程序。（已经实现并上板测试通过）
2. 支持37条指令冒险流水线CPU下板实验并成功运行测试程序。
   说明：数据冒险要求用旁路解决，控制冒险要求用静态预测解决。（已经实现并上板测试通过）
3. 在冒险流水线CPU上实现一个应用并显示效果，应用程序要求包含有实现的37条指令。（跳过，包含于后面的点）
4. 在流水线CPU上实现三种单级中断/异常：异常指令、计数中断和系统调用syscall。（已经实现，待上板测试）
5. 键盘连接后在数码管显示按键值的上板测试路径。（已经实现并上板测试通过）
6. VGA 显示输出和键盘控制方块的上板测试路径。（已经实现，待上板测试）
7. 在流水线CPU上实现复杂的应用。（最终目标）

## 实现要求

### 基本要求

所有直接进入项目的文件都必须放在对应功能的目录下，不能保留在其他目录来引用。

每次完成修改或新增文件后，必须检查对应的文档（README.md 和 AGENTS.md）是否需要更新或记录当前的实现进度。

### 当前正确连接

普通数据 RAM 通路必须是：

```text
SCPU Addr_out[11:2] -> RAM_B.addra
SCPU Data_out       -> dm_controller.Data_write
RAM_B.douta         -> dm_controller.Data_read_from_dm
dm_controller.Data_read -> SCPU.Data_in
dm_controller.Data_write_to_dm -> RAM_B.dina
dm_controller.wea_mem -> RAM_B.wea
```

`MIO_BUS` 只用于外设译码、显示和外设读数据返回。

### 板级接口备忘

板卡为 NEXYS4 A7-100T / `xc7a100tcsg324-1`。VGA 管脚来自 Digilent Nexys A7-100T master XDC：

```text
https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
```

Digilent 说明 Nexys4 DDR 到 Nexys A7 没有需要修改 master XDC 的变化，所以该管脚表适用于当前板子。

本地参考资料：

- PS/2：`ref/PS2接口/PS2KB.v`、`ref/PS2接口/PS2IO.v`
- VGA：`ref/VGA接口/VGA_Scan.v`、`ref/VGA接口/VGAIO.v`

PS/2 约束：

```text
ps2_clk  -> F4, IOSTANDARD LVCMOS33, PULLUP true
ps2_data -> B2, IOSTANDARD LVCMOS33, PULLUP true
```

VGA 约束全部使用 `IOSTANDARD LVCMOS33`：

```text
vga_r[0] -> A3
vga_r[1] -> B4
vga_r[2] -> C5
vga_r[3] -> A4
vga_g[0] -> C6
vga_g[1] -> A5
vga_g[2] -> B6
vga_g[3] -> A6
vga_b[0] -> B7
vga_b[1] -> C7
vga_b[2] -> D7
vga_b[3] -> D8
vga_hs    -> B11
vga_vs    -> B12
```

### 键盘显示测试

- NEXYS4 A7-100T 的 PS/2 端口约束为 `ps2_clk -> F4`、`ps2_data -> B2`。
- `SW15 = 1` 时，数码管显示最近一次按下键的 `{8'h00, ASCII, 8'h00, scan_code}`；`SW15 = 0` 时保持原 CPU/IO 显示。
- 当前键盘测试已在 NEXYS4 A7-100T 上板通过，是硬件直连显示，不经过 CPU、RAM 或 `MIO_BUS`；后续游戏需要键盘输入时再接入 MMIO 或中断。

### VGA 显示测试

- 顶层 VGA 端口为 `vga_r[3:0]`、`vga_g[3:0]`、`vga_b[3:0]`、`vga_hs`、`vga_vs`。
- 当前 VGA 第一阶段是纯 RTL 自检，不接 CPU MMIO，不经过 RAM 或 `MIO_BUS`。
- VGA 使用 100MHz `clk` 产生 25MHz `pixel_tick` 使能，不新增全局派生时钟。
- 当前时序为 `640x480@60Hz`：水平 `640/16/96/48`，垂直 `480/10/2/33`。
- `SW14 = 1` 叠加键盘控制方块，方向键或 WASD 控制移动；`SW14 = 0` 只显示固定色条/边框/中心线。
- 后续游戏建议复用这条 VGA 输出链路，再新增 tile/framebuffer/MMIO；键盘状态可通过 MMIO 或中断机制接入 CPU。

### 流水线与时钟约束

- `SCPU` 是 IF/ID、ID/EX、EX/MEM、MEM/WB 五级流水线。
- 数据冒险主要靠旁路解决：EX/MEM、MEM/WB 到 EX，WB 到 ID，store 写数据使用旁路后的 `rs2`。
- load-use 冒险插入 1 个 bubble。
- 控制冒险使用静态预测：`jal` taken；条件分支后跳 taken、前跳 not taken；`jalr` 在 EX 阶段重定向；预测错误 flush IF/ID 与 ID/EX。
- `RF` 下降沿写回，实例名必须保留为 `U_RF`。
- `SCPU.clk` 接板载 100MHz `clk`，流水线推进由 `SCPU.en` 控制。
- `top.v` 中 `cpu_en` 必须由实际 `Clk_CPU` 的上升沿检测生成，不要硬编码 `clkdiv[n]` 位。
- `clk_div.v` 可以调整 `Clk_CPU` 的分频位；调整后不应再同步修改 `top.v` 的 `cpu_en` 逻辑。
- `RAM_B.clka` 和 IO 写寄存器采样时钟保持接 `~clk`。

### IP 名称要求

- 指令 ROM 模块名：`ROM_D`
- 数据 RAM 模块名：`RAM_B`
- CPU 模块名：`SCPU`
- 访存控制模块名：`dm_controller`

`RAM_B` 需要 32 位数据、10 位地址、4 位字节写使能。

### 版本标记

- `single-cycle-v1`：流水线合并前的单周期版本。
- `pipeline-v1`：通过板上 `testac.coe` 的五级流水线版本。

### 修改原则

- 改 RTL 前先看当前端口名和实例名，不要按记忆改。

### 建议验证

能跑 `iverilog` 时，必须至少做顶层展开检查。若使用 Vivado IP，仿真环境需要对应 IP 仿真模型或 stub。
