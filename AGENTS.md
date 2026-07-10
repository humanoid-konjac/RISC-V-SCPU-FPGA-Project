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

   当前选定应用为 8 试管、6 颜色、2 空管的倒水排序游戏。C 程序负责游戏规则和状态，Verilog 负责按键事件锁存、MMIO 状态寄存器与 VGA 实时渲染，不使用完整帧缓冲。开发子进度如下：

   - [x] Step 1：在电脑端完成纯 C 游戏逻辑，包括固定关卡、光标与选择、倾倒合法性、连续同色移动、胜利判断、取消和重新开始；通过主机单元测试后再移植。（2026-07-10 已实现，严格警告编译、21 步通关回放和 sanitizer 检查通过）
   - [x] Step 2：增加带锁存和确认机制的键盘 MMIO，建立裸机 C 启动、链接和双 COE 构建流程，并用 LED/数码管验证 CPU 不漏读按键。（2026-07-10 RTL 仿真和固件构建通过，待上板）
   - [x] Step 3：增加游戏状态 MMIO、shadow/commit 帧边界切换，先用按键控制 VGA 色块，验证“键盘 -> CPU -> MMIO -> VGA”完整链路。（2026-07-10 模块仿真、旧功能回归、顶层展开和固件构建通过，待上板）
   - [x] Step 4：实现 8 根固定试管的 VGA 实时渲染，验证颜色、层序、位置、光标和来源选中效果。（2026-07-10 关键像素、输出寄存和顶层展开仿真通过，待上板）
   - [x] Step 5：移植完整 C 游戏主循环，接通键盘、试管状态、步数、LED 和通关效果，完成整机仿真与上板验收。（2026-07-10 真实 SCPU 固件 21 步通关仿真通过，待上板）
   - [ ] Step 6：在第一版稳定后再评估撤销、多关卡、倾倒动画、计时、通关动画和伪随机选关；这些功能不属于第一版完成条件。

   第一版固定规格：左右键移动，Enter/Space 选择或倾倒，Esc 取消，R 重新开始；合法倾倒才计步；无动画；步数显示在数码管；通关时 VGA 边框闪烁并让 LED 全亮。每完成一个 Step，必须同步更新本清单、`README.md`、Vivado 导入清单和对应验证结果。

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

数据 RAM 保留 `0x00000000～0x00000fff` 映射，并为裸机 C 增加 `0x10000000～0x10000fff` 别名；两者都必须继续使用 `Addr_out[11:2]` 连接 `RAM_B.addra`。游戏 MMIO 使用 `0xd0000000～0xd0000fff`，不得打开 RAM 写使能。

游戏 MMIO 写使能必须限定为 `cpu_en && mem_w` 的单周期脉冲，不能直接使用可能在 CPU 暂停期间保持的 `mem_w`，否则会重复执行键盘 ACK 或画面 COMMIT。

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
- 键盘直连数码管测试已在 NEXYS4 A7-100T 上板通过；当前同时接入 `keyboard_event_mmio`，把逻辑按键保持到 CPU 写 ACK。MMIO RTL 和完整游戏固件整机仿真已通过，待上板测试。

### VGA 显示测试

- 顶层 VGA 端口为 `vga_r[3:0]`、`vga_g[3:0]`、`vga_b[3:0]`、`vga_hs`、`vga_vs`。
- `SW14=0` 保留纯 RTL 色条和键盘方块自检；`SW14=1` 显示 CPU 游戏 MMIO 画面。
- VGA 使用 100MHz `clk` 产生 25MHz `pixel_tick` 使能，不新增全局派生时钟。
- 当前时序为 `640x480@60Hz`：水平 `640/16/96/48`，垂直 `480/10/2/33`。
- 游戏画面显示 8 根横向试管、四层液体、白色光标下划线、黄色来源框和通关闪烁外边框；状态在 `COMMIT` 后于下一 `frame_tick` 原子切换。
- 测试图/游戏图选择后的 RGB、HS、VS 必须统一经过 `vga_output_register` 寄存后再接顶层管脚，不能把基于 `pixel_x/pixel_y` 的组合译码直接输出；否则计数器位翻转毛刺会在色条或游戏图形中形成固定竖线。

### Vivado 导入清单

设计源必须包含：

- `top.v`
- CPU：`code/SCPU.v`、`code/RF.v`、`code/ctrl.v`、`code/ctrl_encode_def.v`、`code/alu.v`、`code/EXT.v`、`code/dm_controller.v`
- IO：`IO/Counter_3_IO.v`、`IO/Enter.v`、`IO/clk_div.v`、`IO/ps2_keyboard.v`、`IO/keyboard_display.v`、`IO/keyboard_control.v`、`IO/keyboard_event_mmio.v`、`IO/game_state_mmio.v`、`IO/vga_timing.v`、`IO/vga_test_pattern.v`、`IO/vga_game_pattern.v`、`IO/vga_output_register.v`
- 外设：`edf_file/MIO_BUS.V`，以及 `edf_file/Multi_8CH32.v/.edf`、`edf_file/SPIO.v/.edf`、`edf_file/SSeg7.v/.edf`
- 约束：只使用当前 `icf.xdc`
- IP：保留现有 `ROM_D` 和 `RAM_B`，本次不修改或重新生成

`code/simulation/*`、`code/dm.v`、`code/im.v` 只用于仿真；`archive/`、`ref/`、`asm2coe/`、`tmp/` 不加入 Vivado 工程。完成导入后设置顶层为 `top`，依次执行综合、实现和生成 bitstream。

完整裸机固件位于 `software/water_sort/fpga/`，使用 GNU `riscv64-unknown-elf-*` 生成 `coe/water_sort_game_i.coe` 和 `coe/water_sort_game_d.coe`。启动时执行 `isa_coverage.S`，实际覆盖全部 37 条已实现指令。2026-07-10 构建结果为 `.text` 1396 字节、`.bss` 46 字节；真实 `SCPU` 整机仿真已按已知解完成 21 步通关，COE 已纳入仓库，仍需实际上板确认。

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

### 修改原则

- 改 RTL 前先看当前端口名和实例名，不要按记忆改。

### 建议验证

能跑 `iverilog` 时，必须至少做顶层展开检查。若使用 Vivado IP，仿真环境需要对应 IP 仿真模型或 stub。
