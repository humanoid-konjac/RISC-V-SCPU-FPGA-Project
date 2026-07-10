# RISC-V SCPU FPGA Project

这是一个用于 Vivado 下板的五级流水线 RISC-V CPU 工程。当前版本使用自写 `SCPU` 和 `dm_controller`，保留了参考工程中可用的 IO/显示/总线模块。

## 目录结构

- `top.v`: FPGA 顶层，连接 CPU、ROM、RAM、外设总线、数码管、LED、按键、开关、PS/2 键盘和 VGA。
- `code/`: 自写 CPU RTL，包括五级流水线 CPU、控制器、ALU、寄存器堆、立即数扩展、访存控制等。
- `IO/`: 板级 IO RTL，包括按键/开关输入处理、分频器、计数器、PS/2 键盘接收和 VGA 测试显示。
- `edf_file/`: 当前仍在工程中使用的参考工程文件，包括 `MIO_BUS`、`Multi_8CH32`、`SSeg7`、`SPIO` 等 IO/显示/总线模块。
- `archive/`: 已从当前工程移出的旧参考文件，仅作备份归档，不参与综合、实现或仿真。归档文件统一使用 `.bak` 后缀，避免 Vivado 递归添加目录时把旧同名模块当作源文件读入。
- `coe/`: Vivado ROM/RAM IP 初始化文件。
- `software/`: 在 CPU 上运行的应用及其主机端测试；当前包含倒水排序游戏的可移植 C 核心。
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

数据 RAM 同时响应原有 `0x0000_0000～0x0000_0fff` 和 C 裸机程序使用的 `0x1000_0000～0x1000_0fff`，两段地址映射到同一个 `RAM_B`，地址仍使用 `Addr_out[11:2]`。游戏 MMIO 独立使用 `0xd000_0000～0xd000_0fff`，不会进入 RAM 写通路。

## 键盘显示测试

`top.v` 提供 PS/2 键盘直连数码管测试模式：

- `ps2_clk` 约束到 NEXYS4 A7-100T 的 `F4` 管脚。
- `ps2_data` 约束到 NEXYS4 A7-100T 的 `B2` 管脚。
- `SW15 = 1` 时，数码管显示最近一次按下键的 `{8'h00, ASCII, 8'h00, scan_code}`。
- `SW15 = 0` 时，保持原来的 CPU/IO 数码管显示路径。

该直连测试已在 NEXYS4 A7-100T 上板通过。当前新增 `keyboard_event_mmio`，把按键 make 事件转换成 `LEFT/RIGHT/CONFIRM/CANCEL/RESTART` 逻辑码并保持到 CPU 写 ACK；PS/2 break 序列不会产生事件。该 MMIO 路径已通过 RTL 仿真，待使用 Step 3 固件上板验证。

## VGA 显示测试

`top.v` 提供 VGA 直连测试输出，用于先验证显示器物理链路和键盘到画面的反馈：

- 输出端口为 `vga_r[3:0]`、`vga_g[3:0]`、`vga_b[3:0]`、`vga_hs`、`vga_vs`。
- `SW14 = 0` 保留纯 RTL `640x480@60Hz` 色条、边框、中心线和键盘控制方块，用于检查物理显示链路。
- `SW14 = 1` 切换到游戏 MMIO 画面；Step 3 暂时显示一个由 CPU 控制颜色的中央方块，Step 4 再替换为完整试管。
- `SW15` 仍只控制数码管是否显示键盘值，不影响 VGA。

VGA 管脚按 Digilent Nexys A7-100T master XDC 记录，兼容当前 Nexys4 A7-100T：

```text
vga_r[0..3] -> A3 B4 C5 A4
vga_g[0..3] -> C6 A5 B6 A6
vga_b[0..3] -> B7 C7 D7 D8
vga_hs      -> B11
vga_vs      -> B12
```

原 VGA 测试已在 NEXYS4 A7-100T 上板通过。新增的游戏画面选择、状态提交和中央色块已通过 RTL 仿真及顶层展开，待加载 Step 3 固件上板验证。

后续 C 语言小游戏显示建议在这条稳定 VGA 输出链路上扩展 tile/framebuffer/MMIO，不要先把完整显存设计和 VGA 物理调试混在一起。

## 倒水排序游戏开发进度

最终复杂应用选定为倒水排序游戏。第一版使用 8 根试管、6 种颜色和 2 根空管，每根试管最多 4 层；C 程序负责保存状态、判断倾倒、计步和通关，Verilog 负责 PS/2 按键事件锁存、MMIO 状态寄存器和 VGA 按坐标实时渲染。

```text
PS/2 键盘 -> 按键事件寄存器 -> MMIO -> CPU/C 游戏逻辑
                                      -> shadow 状态 + COMMIT
                                      -> VGA 试管渲染器
```

不采用逐像素帧缓冲。CPU 只写 8 根试管、光标、来源、步数和通关状态；VGA 在扫描过程中根据像素坐标和 active 状态生成颜色。游戏状态在 `COMMIT` 后于下一帧边界整体生效，避免多寄存器更新造成画面撕裂。

第一版操作固定为：左右键移动光标，Enter/Space 选择来源或执行倾倒，Esc 取消选择，R 重新开始。合法倾倒才增加步数；步数显示在数码管，通关时使用 VGA 闪烁和 LED 全亮提示。

### 游戏 MMIO

| 地址 | 访问 | 含义 |
|---|---|---|
| `0xd000_0000` | R | `KEY_STATUS`，bit0 为待处理事件 |
| `0xd000_0004` | R | `KEY_CODE`：1 左、2 右、3 确认、4 取消、5 重置 |
| `0xd000_0008` | W | `KEY_ACK`，写 bit0 清除事件 |
| `0xd000_0020～0xd000_003c` | R/W | 8 根试管 shadow 状态 |
| `0xd000_0040` | R/W | UI shadow 状态 |
| `0xd000_0044` | R/W | 步数 shadow 状态 |
| `0xd000_0048` | W | `COMMIT`，拍摄 pending 快照 |

游戏寄存器使用 shadow、pending、active 三组状态。CPU 写 `COMMIT` 时固定 pending 快照，VGA 在下一个 `frame_tick` 整体更新 active；即使 CPU 在帧边界前继续写 shadow，也不会污染已经提交的画面。MMIO 写脉冲由 `cpu_en && mem_w` 限定，避免流水线暂停时重复 ACK 或 COMMIT。

### 分阶段计划

- [x] **Step 1：电脑端纯 C 逻辑。** 完成固定关卡、选择、合法性判断、连续同色倾倒、通关、取消和重置，并通过主机单元测试。
- [x] **Step 2：键盘 MMIO。** 已实现扫描码逻辑事件、单事件锁存、CPU ACK、裸机启动/链接和双 COE 构建流程；RTL 仿真和固件构建通过，待上板确认。
- [x] **Step 3：CPU 控制 VGA 状态。** 已实现 shadow/pending/active 帧提交、CPU 控制中央色块和诊断固件；模块仿真、旧功能回归、顶层展开和固件构建通过，待上板确认。
- [ ] **Step 4：固定试管渲染。** 显示 8 根试管、四层液体、光标和来源选中效果。
- [ ] **Step 5：完整游戏上板。** 移植 C 主循环，接通输入、VGA、步数和通关反馈，完成整机仿真与上板测试。
- [ ] **Step 6：演示增强。** 第一版稳定后再加入撤销、多关卡、动画、计时和伪随机选关。

Step 1 的主机端源代码和测试位于 `software/water_sort/`；Step 2/3 裸机诊断固件位于 `software/water_sort/fpga/`。2026-07-10 已通过主机 C 测试、新增 MMIO/VGA 模块测试、原 PS/2/VGA/VGA 时序回归、`top` 展开和 GNU RV32I 固件构建。当前指令段为 268 字节，数据初始化镜像为一个零字，生成的 `coe/game_phase3_i.coe` 和 `coe/game_phase3_d.coe` 已纳入仓库。

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

### 完整 Vivado 工程加入清单

不要直接递归加入整个仓库。新建或整理 Vivado 工程时，按下面类别加入：

**Design Sources：**

1. 顶层：`top.v`，并在 **Settings -> General -> Top module name** 设为 `top`。
2. CPU RTL：`code/SCPU.v`、`code/RF.v`、`code/ctrl.v`、`code/ctrl_encode_def.v`、`code/alu.v`、`code/EXT.v`、`code/dm_controller.v`。
3. 板级 IO：`IO/Counter_3_IO.v`、`IO/Enter.v`、`IO/clk_div.v`、`IO/ps2_keyboard.v`、`IO/keyboard_display.v`、`IO/keyboard_control.v`、`IO/keyboard_event_mmio.v`、`IO/game_state_mmio.v`、`IO/vga_timing.v`、`IO/vga_test_pattern.v`、`IO/vga_game_pattern.v`。
4. 参考外设模块：`edf_file/MIO_BUS.V`，以及 `edf_file/Multi_8CH32.v/.edf`、`edf_file/SPIO.v/.edf`、`edf_file/SSeg7.v/.edf`。

**Constraints：**

- 在 **Add or Create Constraints** 中只加入根目录 `icf.xdc`，不要保留旧版或重复 XDC。

**IP Sources：**

- 保留或创建指令 ROM `ROM_D`：地址 `a[9:0]`，输出 `spo[31:0]`，初始化文件选择 `coe/game_phase3_i.coe`。
- 保留或创建数据 RAM `RAM_B`：地址 `addra[9:0]`，数据宽度 32 位，字节写使能 `wea[3:0]`，初始化文件选择 `coe/game_phase3_d.coe`。
- COE 文件只在 IP 配置中选择，不作为 Verilog Design Source 加入。修改 COE 后必须重新生成 IP 的 output products。

**不要加入 Design Sources：**

- `code/simulation/*`、`code/dm.v`、`code/im.v` 仅用于仿真。
- `software/` 是固件源代码，`coe/` 是 IP 初始化数据，都不是 RTL Design Source。
- `archive/`、`ref/`、`asm2coe/`、`tmp/` 和各类 `build/` 目录不加入工程。

`ROM_D` 与 `RAM_B` 是已有 Vivado IP，端口和容量不变；使用 Step 3 固件时只需分别更换初始化 COE 并重新生成 output products：

- `ROM_D`：模块名 `ROM_D`，地址 `a[9:0]`，数据输出 `spo[31:0]`。
- `RAM_B`：模块名 `RAM_B`，地址 `addra[9:0]`，数据 `dina/douta[31:0]`，字节写使能 `wea[3:0]`，时钟 `clka`。

### Step 2/3 上板测试

1. 仓库已包含验证过的 `coe/game_phase3_i.coe` 和 `coe/game_phase3_d.coe`。修改固件后，在 `software/water_sort/fpga/` 执行 `make` 重新生成；同时查看 `build/game_phase3.asm`，确认没有 M 扩展或未解析运行库调用。
2. 在 Vivado 中把 `ROM_D` 初始化文件改为 `game_phase3_i.coe`，把 `RAM_B` 初始化文件改为 `game_phase3_d.coe`，重新生成两个 IP 的 output products。
3. 按上面的清单加入三个新增 IO 文件，确认顶层仍为 `top`，依次运行 **Synthesis**、**Implementation**、**Generate Bitstream**。
4. 接好 VGA 和 PS/2 键盘，下载 bitstream；设置 `SW2=0` 使用快速 CPU，`SW14=1` 显示游戏色块，`SW15=0` 显示 CPU/IO 数码管数据，`SW7:5=000` 选择固件写入的显示通道。
5. 复位后中央方块应为红色。按右方向键或 D，颜色按红、绿、蓝、黄、紫、青循环；按左方向键或 A 反向循环；按 R 恢复红色。每次按键 LED 和数码管显示逻辑码 `1～5`。
6. 分别测试 Enter/Space 为 `3`、Esc 为 `4`、R 为 `5`；长按和连续点击后确认一次事件只处理一次且画面稳定。`SW15=1` 可同时回到原始扫描码直连诊断。
7. 将 `SW14=0`，确认原色条、边框、中心线及键盘移动方块仍正常，以排除 VGA 物理链路回归。

若中央方块保持灰色，优先检查 `ROM_D` 是否确实使用新指令 COE、是否重新生成 output products，以及 `SW2/SW14` 是否为 `0/1`。若 LED 有键码但颜色不变，检查 `game_state_mmio.v` 是否加入 Design Sources；若 `SW15=1` 有扫描码但 LED 无变化，检查键盘 MMIO 文件和固件 COE。

原有板级自检方式仍保留：

- `SW14 = 0`：确认 VGA 色条、白色边框、中心线和键盘方块稳定显示。
- `SW14 = 1`：进入 CPU 游戏 MMIO 画面。
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
