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
6. VGA 显示输出和键盘控制方块的上板测试路径。（已经实现并上板测试通过）
7. 在流水线CPU上实现复杂的应用。（最终目标）

当前音频分支进度：已实现板载 PDM 麦克风接收、声音触发、音频/视频 MMIO、裸机 C/RV32I Voice Flap 固件、VGA 游戏渲染和 Icarus 回归；Vivado 综合/实现及实物板灵敏度复测仍需在有 Vivado 和 Nexys A7/Nexys 4 DDR 的环境执行。

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

板载 ADMP421 PDM 麦克风约束：

```text
mic_clk   -> J5, LVCMOS33
mic_data  -> H5, LVCMOS33
mic_lrsel -> F5, LVCMOS33
```

麦克风时钟为 2.5MHz，`mic_lrsel=0`。音频逻辑必须保持在 100MHz `clk` 域并使用 clock-enable，不允许用 `mic_clk` 建立新的内部 always 时钟域。

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

### Voice Flap 声控游戏

- `SW13=1` 选择游戏，`SW13=0` 保留原 VGA 测试路径。
- `SW12=1` 选择麦克风数码管诊断，`SW15` 的键盘显示优先级更高。
- `SW11=1` 为人声高灵敏模式（增益 x8、阈值 margin `2/1`），`SW11=0` 为普通模式（增益 x4、margin `3/1`）；模式切换必须触发重新校准。
- `SW2=0` 才是游戏运行速度。
- 中心按钮上升沿以及键盘 `W`/方向键上/空格的按下沿作为人工声音事件，用于板上隔离麦克风与游戏问题；键盘自动连发必须被抑制到松开再按。
- 麦克风自动校准约 0.53 秒；事件必须 sticky，直到 CPU 向 `MIC_STATUS.bit1` 写 1 清除。
- 声音使用“一声一跳”：约 6.5 ms 人声能量包络、3.3 ms 确认、100 ms 冷却、30 ms 安静重新武装；持续高声不能重复触发。
- 游戏跳跃初速度为 `-10`，同帧重力后净速度 `-9`，一次事件完整上升约 45 像素。
- 默认宽容难度：160 像素缺口、管道每帧移动 2 像素、碰撞框内缩、3 条命、碰撞后约 60 帧保护，第三次碰撞才 Game Over。
- 游戏渲染保持无 framebuffer：使用三帧 16x12 掩码按 2x 显示机械鸟，并程序化绘制粒子、管道 tile、云/城市/双层山景、草地/石块、分数、麦克风 UI、生命和覆盖文字。
- 当前使用 CPU 轮询，不把麦克风与 `counter0_OUT` 直接 OR 到 `SCPU.INT`。
- Voice Flap 主源码为 `software/voice_game.c`，由 GNU RISC-V bare-metal GCC 以 `rv32i/ilp32`、freestanding、nostdlib 模式交叉编译；`audit_rv32i.py` 必须继续审计生成指令。ROM 文件为 `coe/voice_game.coe`，旧 `voice_game.asm` 只作迁移参考。

### 新增 MMIO

```text
0xC0000000-0xC0000018  游戏视频寄存器
0xD0000000-0xD000001C  麦克风寄存器
0xE...                  原按钮/开关/显示
0xF...                  原 LED/计数器
```

新 MMIO 只支持对齐的 32 位 `lw/sw`。由于 `mem_w` 会在两个 `cpu_en` 之间保持，`mic_mmio` 和 `video_mmio` 的写使能必须继续使用 `mio_*_we && cpu_en` 的单 CPU 事务脉冲，不能直接使用原始 `mem_w`。

### Vivado 导入清单

设计源必须包含：

- `top.v`
- CPU：`code/SCPU.v`、`code/RF.v`、`code/ctrl.v`、`code/ctrl_encode_def.v`、`code/alu.v`、`code/EXT.v`、`code/dm_controller.v`
- IO：`IO/Counter_3_IO.v`、`IO/Enter.v`、`IO/clk_div.v`、`IO/ps2_keyboard.v`、`IO/keyboard_display.v`、`IO/keyboard_control.v`、`IO/vga_timing.v`、`IO/vga_test_pattern.v`、`IO/mic_pdm_rx.v`、`IO/mic_voice_trigger.v`、`IO/mic_mmio.v`、`IO/video_mmio.v`、`IO/vga_game_renderer.v`
- 外设：`edf_file/MIO_BUS.V`，以及 `edf_file/Multi_8CH32.v/.edf`、`edf_file/SPIO.v/.edf`、`edf_file/SSeg7.v/.edf`
- 约束：只使用当前 `icf.xdc`
- IP：保留现有 `ROM_D` 和 `RAM_B` 端口；Voice Flap 下板时 `ROM_D` 必须改用 `coe/voice_game.coe` 并重新生成 output products

`code/simulation/*`、`code/dm.v`、`code/im.v` 只用于仿真；`archive/`、`ref/`、`asm2coe/`、`tmp/` 不加入 Vivado 工程。完成导入后设置顶层为 `top`，依次执行综合、实现和生成 bitstream。

`code/simulation/top_ip_stubs.v` 只用于 Icarus 顶层展开，绝对不能加入 Vivado design sources。

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
- `interrupt-v1`：包含单级中断/异常、PS/2 键盘和 VGA 上板测试的当前版本。
- `feature/audio-microphone`：PDM 麦克风、MMIO、RV32I 固件和 Voice Flap 游戏分支。

### 修改原则

- 改 RTL 前先看当前端口名和实例名，不要按记忆改。

### 建议验证

能跑 `iverilog` 时，必须至少做顶层展开检查。若使用 Vivado IP，仿真环境需要对应 IP 仿真模型或 stub。

音频分支完整回归命令：

```bash
./scripts/run_tests.sh
```

固件刷新命令：

```bash
make -C software
```

有 Vivado 时的完整 bitstream 构建命令：

```bash
vivado -mode batch -source vivado/build_voice_game.tcl
```
