# RISC-V SCPU FPGA Project

这是一个用于 Vivado 下板的五级流水线 RISC-V CPU 工程。当前音频分支在原有 CPU、PS/2 和 VGA 基础上增加了板载 PDM 麦克风、声音事件检测、MMIO 和由裸机 C 固件驱动的 Voice Flap 声控游戏。

## 目录结构

- `top.v`: FPGA 顶层，连接 CPU、ROM、RAM、外设总线、数码管、LED、按键、开关、PS/2 键盘和 VGA。
- `code/`: 自写 CPU RTL，包括五级流水线 CPU、控制器、ALU、寄存器堆、立即数扩展、访存控制等。
- `IO/`: 板级 IO RTL，包括按键/开关输入处理、分频器、计数器、PS/2 键盘接收和 VGA 测试显示。
- `edf_file/`: 当前仍在工程中使用的参考工程文件，包括 `MIO_BUS`、`Multi_8CH32`、`SSeg7`、`SPIO` 等 IO/显示/总线模块。
- `archive/`: 已从当前工程移出的旧参考文件，仅作备份归档，不参与综合、实现或仿真。归档文件统一使用 `.bak` 后缀，避免 Vivado 递归添加目录时把旧同名模块当作源文件读入。
- `coe/`: Vivado ROM/RAM IP 初始化文件。
- `software/`: Voice Flap 裸机 C 源码、RV32I 启动/链接文件、交叉编译 Makefile、ROM 转换和指令审计工具。
- `scripts/`: 一键 RTL/CPU/系统回归脚本。
- `vivado/`: 从空目录创建工程、综合、实现和生成 bitstream 的批处理脚本。
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

当前 Voice Flap 复用这条稳定 VGA 输出链路，使用对象寄存器和直接像素渲染，不依赖完整 framebuffer。

## 板载麦克风与 Voice Flap

Nexys A7-100T / Nexys 4 DDR 的板载 ADMP421 麦克风输出 PDM 数据。当前实现使用 100MHz 系统时钟产生 2.5MHz `mic_clk`，`mic_lrsel=0`，每 128 个 PDM bit 生成一个约 19.53kHz 的抽取样本。内部逻辑始终运行在 100MHz 时钟域，只使用 clock-enable，不把 `mic_clk` 作为内部派生时钟。

管脚为：

```text
mic_clk   -> J5, LVCMOS33
mic_data  -> H5, LVCMOS33
mic_lrsel -> F5, LVCMOS33
```

声音处理链为：

```text
PDM 密度统计 -> 去直流 -> 数字增益 -> 约 6.5 ms 人声能量包络
             -> 环境噪声校准 -> 3.3 ms 确认 -> 双阈值/冷却
             -> 30 ms 安静重新武装 -> sticky event
```

上电复位后约 0.53 秒完成自动校准。游戏画面左上角橙色方块表示正在校准，绿色表示麦克风已就绪；旁边的横条显示声音等级。中心按钮、键盘 `W`/方向键上/空格和真实声音共用同一个 sticky event，可用于不依赖麦克风的板上故障隔离。键盘按下沿只触发一次，自动连发不会造成连续跳跃，松开后再次按下才能再次触发。

声音控制采用“一声一跳”。`SW11=0` 为普通灵敏度（数字增益 x4、阈值 margin `+3/+1`），`SW11=1` 为人声高灵敏度（数字增益 x8、阈值 margin `+2/+1`）；切换模式会自动重新校准。约 3.3 ms 的持续人声能量可触发一次事件，持续大声不会连续触发，恢复安静约 30 ms 后，下一个短促音节可再次触发。防抖冷却约 100 ms。

C 固件使用 `-10` 的跳跃初速度，位于旧版 `-7` 与上一版 `-12` 之间；触发帧的净速度为 `-9`，一次完整上升约 45 像素。默认宽容玩法使用 160 像素管道缺口、每帧 2 像素管道速度、缩小的角色碰撞框、3 条生命和碰撞后约 1 秒保护。第三次碰撞才进入 Game Over，再次发声或按键可恢复 3 条生命重新开始。

Voice Flap 由 CPU 每个 VGA 帧更新一次：声音事件产生向上速度，无声音时受重力下落，CPU 负责碰撞、障碍、生命、保护帧、分数和游戏状态。VGA RTL 使用小型像素掩码和程序化 tile 渲染三帧机械鸟、粒子、带端帽/高光的管道、云、城市、双层远山、草地石块、像素分数、麦克风能量条、生命心和 READY/GAME OVER 字样；未使用完整 framebuffer。

实际 RTL 逐像素渲染预览见 `docs/game_preview.png`。该图由 `code/simulation/vga_game_frame_tb.v` 生成，不是概念图。

### MMIO 地址

麦克风基地址为 `0xD0000000`，仅使用对齐的 `lw/sw`：

| 偏移 | 名称 | 说明 |
| --- | --- | --- |
| `0x00` | `MIC_CONTROL` | bit0 使能，bit1 重新校准脉冲，bit2 手动阈值使能 |
| `0x04` | `MIC_STATUS` | bit0 校准完成，bit1 event pending，bit2 超过阈值；向 bit1 写 1 清事件 |
| `0x08` | `MIC_LEVEL` | 当前声音包络 |
| `0x0c` | `MIC_PCM` | 最近一个有符号抽取样本 |
| `0x10` | `MIC_THRESHOLD` | `[15:0]` 高阈值，`[31:16]` 低阈值配置 |
| `0x14` | `MIC_NOISE` | 自动校准得到的环境噪声 |
| `0x18` | `MIC_EVENT_SEQ` | 每次事件递增 |
| `0x1c` | `MIC_THRESHOLD_EFFECTIVE` | 当前实际使用的高/低阈值 |

视频基地址为 `0xC0000000`：

| 偏移 | 名称 | 说明 |
| --- | --- | --- |
| `0x00` | `GAME_CONTROL` | bit0 使能，bit1 waiting/game-over |
| `0x04` | `PLAYER_Y` | 玩家纵坐标 |
| `0x08` | `OBSTACLE_X` | 障碍物横坐标 |
| `0x0c` | `GAP_Y` | 障碍缺口中心 |
| `0x10` | `SCORE` | 低 16 位分数，VGA 显示低两个十六进制数字 |
| `0x14` | `FRAME_SEQUENCE` | 每个 VGA 帧递增，软件用它锁定 60Hz 更新 |
| `0x18` | `GAME_STATUS` | bit1:0 生命数，bit8 受伤保护/闪烁状态 |

第一版使用轮询，不把麦克风直接并入 CPU 中断，避免当前单一计时器中断入口丢失来源信息。

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

## 固件与仿真

当前游戏主源码为 `software/voice_game.c`，`software/voice_game.asm` 仅保留为迁移前参考。安装 GNU RISC-V bare-metal 工具链后生成或刷新游戏 ROM：

```bash
make -C software
```

Homebrew 工具链使用默认前缀 `riscv64-elf-`；使用常见的 `riscv64-unknown-elf-` 工具链时执行：

```bash
make -C software CROSS=riscv64-unknown-elf-
```

构建固定使用 `-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib`，并自动审计反汇编，拒绝 CPU 未实现的指令。输出包括：

```text
software/voice_game.elf
software/voice_game.bin
software/voice_game.hex
software/voice_game.lst
software/voice_game.map
coe/voice_game.coe
```

当前 ELF 为 564 字节，`.data/.bss` 均为 0，使用 4 KB ROM 的约 14%。只在 Vivado 中生成 bitstream 时可直接使用仓库内已经生成的 `coe/voice_game.coe`，无需在 Vivado 电脑重复安装 RISC-V 工具链。

安装 `iverilog` 后运行完整回归：

```bash
./scripts/run_tests.sh
```

回归会先交叉编译 C 固件，再让真实五级流水线 CPU 执行生成的 ROM；随后覆盖 PDM 前端、一声一跳/持续声音抑制、音频/视频 MMIO、VGA 像素、原 37 指令 CPU、异常/中断、PS/2、VGA 时序，以及使用仿真 IP stub 的顶层展开检查。

## 一键 Vivado 构建

在能运行 Vivado 的终端执行：

```bash
make -C software
vivado -mode batch -source vivado/build_voice_game.tcl
```

脚本以 `xc7a100tcsg324-1` 创建工程，创建 `ROM_D`/`RAM_B` IP，运行综合、实现、DRC 和 bitstream。成功后的文件位于：

```text
build/artifacts/voice_game.bit
build/artifacts/post_route_timing.rpt
build/artifacts/post_route_utilization.rpt
build/artifacts/post_route_drc.rpt
```

本仓库不提交 Vivado 生成目录和 bitstream。

## Vivado 导入与上板

在已有 Vivado 工程中，保留现有 `ROM_D`、`RAM_B` IP，执行 **Add Sources -> Add or Create Design Sources**，补齐下列文件；若文件已经存在于工程中，不要重复添加。

1. 顶层：`top.v`，并在 **Settings -> General -> Top module name** 设为 `top`。
2. CPU RTL：`code/SCPU.v`、`code/RF.v`、`code/ctrl.v`、`code/ctrl_encode_def.v`、`code/alu.v`、`code/EXT.v`、`code/dm_controller.v`。
3. 板级 IO：`IO/Counter_3_IO.v`、`IO/Enter.v`、`IO/clk_div.v`、`IO/ps2_keyboard.v`、`IO/keyboard_display.v`、`IO/keyboard_control.v`、`IO/vga_timing.v`、`IO/vga_test_pattern.v`、`IO/mic_pdm_rx.v`、`IO/mic_voice_trigger.v`、`IO/mic_mmio.v`、`IO/video_mmio.v`、`IO/vga_game_renderer.v`。
4. 参考外设模块：`edf_file/MIO_BUS.V`，以及 `edf_file/Multi_8CH32.v/.edf`、`edf_file/SPIO.v/.edf`、`edf_file/SSeg7.v/.edf`。
5. 约束：在 **Add or Create Constraints** 中只加入当前的 `icf.xdc`，不要保留旧版或重复的 XDC。

以下文件仅用于仿真，不加入 **Design Sources**：`code/simulation/*`、`code/dm.v`、`code/im.v`。`archive/`、`ref/`、`asm2coe/`、`tmp/` 也不加入工程。特别是 `code/simulation/top_ip_stubs.v` 绝对不能加入 Vivado design sources。

`ROM_D` 与 `RAM_B` 是 Vivado IP。Voice Flap 需要把 `ROM_D` 的初始化文件切换为 `coe/voice_game.coe`；修改固件后必须重新生成 ROM IP output products：

- `ROM_D`：模块名 `ROM_D`，地址 `a[9:0]`，数据输出 `spo[31:0]`。
- `RAM_B`：模块名 `RAM_B`，地址 `addra[9:0]`，数据 `dina/douta[31:0]`，字节写使能 `wea[3:0]`，时钟 `clka`。

导入完成后依次运行 **Synthesis**、**Implementation**、**Generate Bitstream**。上板时连接 VGA，下载 Voice Flap bitstream 后：

- `SW14 = 0`：确认 VGA 色条、白色边框和中心线稳定显示。
- `SW14 = 1`：用方向键或 WASD 移动 VGA 方块。
- `SW13 = 1`：切换到 Voice Flap 游戏画面；`SW13 = 0` 保留原 VGA 测试图。
- `SW11 = 1`：推荐的人声高灵敏度；`SW11 = 0` 为普通灵敏度。切换后保持安静约 0.53 秒等待重新校准。
- `SW12 = 1`：数码管显示 `A0` 前缀、校准/事件标志和麦克风等级。
- `SW15 = 1`：数码管显示最近一次键盘按下值；`SW15 = 0`：恢复原 CPU/IO 数码管显示。
- `SW2 = 0`：游戏运行速度；`SW2 = 1` 是低速观察模式，不能正常玩游戏。
- 复位后设置 `SW11=1` 并保持环境安静约 0.53 秒，等待画面左上角状态块变绿，再用短促的“哈/嘿/啊”触发；持续发声不会连续触发，音节间留约 30 ms 安静间隔。
- 中心按钮、键盘 `W`、方向键上或空格等效于一次声音事件，可用于启动、跳跃和重新开始。

不要把 `archive/` 加入 Vivado source set。里面是旧的 `MIO_BUS`、`SCPU`、`dm_controller` 参考实现，只用于备份。

## 版本标记

- `single-cycle-v1`: 合并流水线前的单周期 CPU 版本。
- `pipeline-v1`: 当前通过板上 `testac.coe` 的五级流水线 CPU 版本。
- `interrupt-v1`: 中断/异常、PS/2 和 VGA 基线版本。
- `feature/audio-microphone`: PDM 麦克风、MMIO 和 Voice Flap 声控游戏开发分支。

## `dm_controller`

`dm_controller` 处理 CPU 的 load/store 访存格式：

- word：直接读写 32 位。
- halfword：按 `Addr_in[1]` 选择高/低 16 位，并做符号扩展。
- halfword unsigned：按 `Addr_in[1]` 选择高/低 16 位，并做零扩展。
- byte：按 `Addr_in[1:0]` 选择字节，并做符号扩展。
- byte unsigned：按 `Addr_in[1:0]` 选择字节，并做零扩展。

写内存时，`Data_write_to_dm` 负责把待写数据放到正确字节 lane，`wea_mem[3:0]` 负责只写对应字节。
