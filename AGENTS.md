# AGENTS.md

本文件用于维护最终交付版本。后续代理必须使用中文回复，并在修改前阅读当前文件和相关源代码。

## 项目基线

- 分支：`game`
- 板卡：Nexys4 A7-100T，器件 `xc7a100tcsg324-1`
- 顶层：`top.v`
- CPU：自研 RV32I 五级流水线 `SCPU`
- 应用：36 关倒水排序游戏
- 输入：PS/2 键盘事件触发机器模式中断
- 输出：`640×480@60Hz` VGA、LED、数码管
- 存储：`ROM_D` 与 `RAM_B` 均为 1024×32

最终交付状态：单周期、流水线、中断/异常、键盘、VGA 和中断驱动完整游戏均已完成课程验收；主机、RTL 与真实 SCPU 回归也已通过。

## 目录职责

- `code/`：CPU RTL、访存控制和仿真。
- `IO/`：板级输入输出、键盘事件、游戏状态和 VGA。
- `edf_file/`：当前仍使用的参考外设。
- `coe/`：课程测试和最终游戏初始化文件。
- `software/water_sort/`：可移植游戏核心、测试和关卡生成器。
- `software/water_sort/fpga/`：裸机固件。
- `icf.xdc`：唯一有效约束。

不得重新加入已删除的 `archive/`、Step 3 诊断固件或 `game_phase3_*.coe`。构建目录、波形、Vivado 输出和 `.DS_Store` 不得提交。

## 不可破坏的连接

普通数据 RAM 必须保持直连：

```text
SCPU Addr_out[11:2] -> RAM_B.addra
SCPU Data_out       -> dm_controller.Data_write
RAM_B.douta         -> dm_controller.Data_read_from_dm
dm_controller.Data_read -> SCPU.Data_in
dm_controller.Data_write_to_dm -> RAM_B.dina
dm_controller.wea_mem -> RAM_B.wea
```

- `MIO_BUS` 只负责旧外设，不得接管 RAM。
- RAM 地址 `0x00000000～0x00000fff` 与 `0x10000000～0x10000fff` 是同一物理 RAM 的别名，均使用 `Addr_out[11:2]`。
- 游戏 MMIO 为 `0xd0000000～0xd0000fff`，不得打开 RAM 写使能。
- 游戏 MMIO 写使能必须是 `cpu_en && mem_w && game_access`，避免 CPU 暂停期间重复 ACK 或 COMMIT。
- `RAM_B.clka` 和旧 IO 写寄存器继续使用 `~clk`。

## CPU 与中断约束

- 流水级为 IF/ID、ID/EX、EX/MEM、MEM/WB。
- 保留 EX/MEM、MEM/WB 到 EX 的旁路，WB 到 ID 的旁路和 store 数据旁路。
- load-use 插入一个 bubble。
- 静态预测：`jal` taken；条件分支后跳 taken、前跳 not taken；`jalr` 在 EX 重定向；错误时 flush IF/ID 与 ID/EX。
- `RF` 下降沿写回，实例名必须为 `U_RF`。
- `SCPU.clk` 接 100 MHz，流水线只由 `SCPU.en` 推进。
- `cpu_en` 必须由实际 `Clk_CPU` 上升沿检测产生，不得硬编码某一 `clkdiv` 位。

CPU实现非法指令、`ecall` 和计数中断，使用 `mstatus/mie/mtvec/mepc/mcause`。键盘 `key_ready` 上升沿和 `counter0_OUT` 上升沿在顶层合并到单个 `INT`。

最终游戏必须保持中断驱动：

- `startup.S` 设置 `mtvec`，开启 `mstatus.MIE` 和 `mie.MTIE`。
- `trap_entry` 保存/恢复除 `x0/sp` 外的整数寄存器并以 `mret` 返回。
- `keyboard_interrupt_handler` 读取 `KEY_CODE`、更新状态、提交画面并写 `KEY_ACK`。
- 主循环不得重新轮询 `KEY_STATUS`。

## 游戏与 MMIO

最终参数：

| 难度 | 颜色 | 空管 | 有效管 | 关卡 |
|---|---:|---:|---:|---:|
| EASY | 4 | 2 | 6 | 12 |
| NORMAL | 6 | 1 | 7 | 12 |
| HARD | 7 | 1 | 8 | 12 |

每次合法倾倒用 1 字节记录来源、目标和层数，历史容量 2048；历史满后拒绝新倾倒，以保证可以撤回开局。

游戏 MMIO：

| 地址 | 含义 |
|---|---|
| `0xd0000000` | KEY_STATUS |
| `0xd0000004` | KEY_CODE |
| `0xd0000008` | KEY_ACK |
| `0xd0000020～0xd000003c` | 8 根试管 shadow 状态 |
| `0xd0000040` | UI shadow |
| `0xd0000044` | 步数 shadow |
| `0xd0000048` | COMMIT |
| `0xd000004c` | 难度、管数和步数 BCD |
| `0xd0000050` | 两位 BCD 关卡号 |

游戏画面必须保持 `shadow -> pending -> active`：COMMIT 固定 pending，`frame_tick` 时整体切换 active。

## VGA 与板级接口

- 100 MHz 时钟产生 25 MHz `pixel_tick` 使能，不创建新的全局派生时钟。
- 时序为水平 `640/16/96/48`、垂直 `480/10/2/33`。
- `SW14=0` 为色条/键盘方块自检，`SW14=1` 为游戏。
- RGB、HS、VS 必须在画面选择后统一经过 `vga_output_register`，不得直接输出组合像素逻辑。
- `SW15=1` 显示 `{8'h00, ASCII, 8'h00, scan_code}`，`SW15=0` 恢复 CPU/IO 显示。

PS/2：`ps2_clk=F4`、`ps2_data=B2`，均为 LVCMOS33 并启用 PULLUP。

VGA：

```text
R: A3 B4 C5 A4
G: C6 A5 B6 A6
B: B7 C7 D7 D8
HS: B11
VS: B12
```

## Vivado source set

必须加入：

- `top.v`
- `code/SCPU.v`、`RF.v`、`ctrl.v`、`ctrl_encode_def.v`、`alu.v`、`EXT.v`、`dm_controller.v`
- `IO/Counter_3_IO.v`、`Enter.v`、`clk_div.v`、`ps2_keyboard.v`、`keyboard_display.v`、`keyboard_control.v`、`keyboard_event_mmio.v`、`game_state_mmio.v`、`vga_timing.v`、`vga_test_pattern.v`、`vga_game_text.v`、`vga_game_pattern.v`、`vga_output_register.v`
- `edf_file/MIO_BUS.V`、`Multi_8CH32.v/.edf`、`SPIO.v/.edf`、`SSeg7.v/.edf`
- 约束只使用 `icf.xdc`

不要加入 `code/simulation/`、`code/dm.v`、`code/im.v`、`software/`、`ref/`、`asm2coe/`、构建目录或 COE 文件本身。

IP 名称和端口：

- `ROM_D`：`a[9:0]`、`spo[31:0]`
- `RAM_B`：`addra[9:0]`、`dina/douta[31:0]`、`wea[3:0]`、`clka`

最终初始化只使用 `water_sort_game_i.coe` 和 `water_sort_game_d.coe`。更换 COE 后重新生成 output products，不要重建或改名 IP。

## 固件约束

- 编译目标必须是 RV32I/ILP32、freestanding、无标准库。
- `.text` 放 ROM；`.rodata/.data/.bss/stack` 放 RAM。
- 关卡目录位于数据 RAM，不能放指令 ROM 后再用普通 load 读取。
- ROM/RAM 各不得超过 4 KiB，并保留至少 512 字节栈。
- `isa_coverage.S` 必须保留，以保证最终应用镜像包含课程要求的 37 条指令。
- 当前尺寸：`.text` 3204、`.rodata` 576、`.bss` 2112 字节。

## 修改和验证流程

1. 修改前查看当前端口和实例名，不按记忆改 RTL。
2. 修改文件后同步检查根 README、AGENTS 和对应子目录 README。
3. 运行 `git diff --check`，确认无生成产物被跟踪。
4. 运行电脑端 `make test`。
5. 构建 FPGA 固件并检查尺寸与反汇编。
6. 运行受影响的模块测试、37 指令、中断异常和真实 SCPU 固件测试。
7. 能运行 `iverilog` 时必须完成顶层展开；Vivado IP 使用仿真 stub 或官方模型。

不得用测试通过代替上板结论。文档必须明确区分“RTL/整机仿真通过”和“已上板通过”。

## 开发记录

- Step 1～5：纯 C 规则、键盘 MMIO、VGA 状态链、试管渲染和完整固定关卡游戏。
- Step 6.1～6.6：动态难度、36 个 BFS 验证关卡、2048 步撤销、菜单、5×7 字库和可复现生成器。
- Step 7：键盘输入改为机器模式中断，trap 完整保存/恢复现场，C ISR 处理事件；真实 SCPU 整机仿真及课程验收通过。
- 最终整理：课程要求全部验收通过；移除阶段性固件、旧备份和生成产物，根 README 聚焦使用与交付，维护细节集中在本文件。

版本标签：`single-cycle-v1`、`pipeline-v1`、`interrupt-v1`。
