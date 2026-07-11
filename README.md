# RISC-V SCPU FPGA Project

这是一个面向 Nexys4 A7-100T（`xc7a100tcsg324-1`）的计算机系统综合设计项目。项目在自研 RV32I 五级流水线 CPU 上实现中断/异常、PS/2 键盘、VGA 输出和裸机 C 应用，最终应用为倒水排序游戏。

当前 `game` 分支是课程验收通过的最终交付版本。游戏包含三档难度、每档 12 个离线求解验证关卡、2048 步撤销、英文菜单和完整板级交互；键盘输入使用机器模式中断，画面不使用帧缓冲。

## 功能与验收状态

| 项目 | 状态 |
|---|---|
| 37 条指令单周期 CPU | 已实现并上板通过 |
| 37 条指令五级流水线 CPU | 已实现并上板通过 |
| 旁路、load-use 暂停、静态分支预测 | 已实现并通过回归 |
| 非法指令、`ecall`、计数中断 | 已实现并通过课程验收 |
| PS/2 键盘数码管自检 | 已上板通过 |
| VGA 色条和键盘方块自检 | 已上板通过 |
| 完整倒水排序游戏 | 主机、RTL、真实 SCPU 整机仿真及课程验收全部通过 |

## 目录

- `top.v`：FPGA 顶层。
- `code/`：CPU、访存控制和仿真测试。
- `IO/`：键盘、游戏 MMIO、VGA 和板级 IO。
- `edf_file/`：仍在工程中使用的参考外设模块。
- `coe/`：ROM/RAM 初始化文件；完整游戏只使用 `water_sort_game_i.coe` 和 `water_sort_game_d.coe`。
- `software/water_sort/`：可移植 C 游戏核心、测试和关卡生成器。
- `software/water_sort/fpga/`：RV32I 裸机固件、启动代码、链接脚本和 COE 构建流程。
- `icf.xdc`：当前唯一板级约束文件。

`ref/` 和 `asm2coe/` 是本地参考资料，不属于最终 Vivado source set，也不进入 Git。

## 游戏操作

上电复位后进入菜单，默认选择 `NORMAL / LEVEL 01`。

菜单：

- `W/S` 或上下方向键：切换 EASY、NORMAL、HARD。
- `A/D` 或左右方向键：循环选择 1～12 关。
- 数字键：直接输入关卡号；Backspace 删除。
- Enter 或 Space：开始游戏。

游戏：

- `A/D` 或左右方向键：移动光标。
- Enter 或 Space：选择来源或执行倾倒。
- Esc：取消选择。
- `U`：撤销一步，可一直撤回开局，通关后也可撤销。
- `R`：重开当前关。
- `M`：返回菜单。

EASY、NORMAL、HARD 分别使用 6/7/8 根试管和 4/6/7 种颜色。数码管显示步数，LED 显示光标，通关后 LED 全亮并显示 `YOU WIN`。

## 构建与测试

### 电脑端游戏核心

```bash
cd software/water_sort
make test
make run
```

`make test` 会重建并核对关卡目录，然后验证 36 个关卡、游戏规则、重开和撤销。关卡生成算法见 `software/water_sort/LEVEL_GENERATION.md`。

### FPGA 裸机固件

需要 RISC-V GNU 工具链，默认前缀为 `riscv64-unknown-elf-`：

```bash
cd software/water_sort/fpga
make
```

构建会生成：

- `coe/water_sort_game_i.coe`：`ROM_D` 指令初始化。
- `coe/water_sort_game_d.coe`：`RAM_B` 数据和关卡初始化。
- `build/*.mem`：真实 SCPU 整机仿真镜像。
- `build/water_sort_game.asm`：反汇编与 37 指令覆盖检查。

链接脚本限制 ROM/RAM 各 4 KiB，并至少保留 512 字节栈。最终中断版固件尺寸为 `.text` 3204 字节、`.rodata` 576 字节、`.bss` 2112 字节。

## Vivado 工程

目标器件为 `xc7a100tcsg324-1`，顶层设为 `top`。

Design Sources：

- 顶层：`top.v`
- CPU：`code/SCPU.v`、`RF.v`、`ctrl.v`、`ctrl_encode_def.v`、`alu.v`、`EXT.v`、`dm_controller.v`
- IO：`IO/Counter_3_IO.v`、`Enter.v`、`clk_div.v`、`ps2_keyboard.v`、`keyboard_display.v`、`keyboard_control.v`、`keyboard_event_mmio.v`、`game_state_mmio.v`、`vga_timing.v`、`vga_test_pattern.v`、`vga_game_text.v`、`vga_game_pattern.v`、`vga_output_register.v`
- 外设：`edf_file/MIO_BUS.V`、`Multi_8CH32.v/.edf`、`SPIO.v/.edf`、`SSeg7.v/.edf`

Constraints 只加入根目录 `icf.xdc`。

IP Sources：

- `ROM_D`：32 位数据、10 位地址，初始化为 `coe/water_sort_game_i.coe`。
- `RAM_B`：32 位数据、10 位地址、4 位字节写使能，初始化为 `coe/water_sort_game_d.coe`。

COE 不是 Design Source。替换 COE 后，对 `ROM_D` 和 `RAM_B` 执行 **Reset Output Products** 和 **Generate Output Products**，再重新综合、实现并生成 bitstream；不需要重新创建 IP。

不要加入 `code/simulation/`、`code/dm.v`、`code/im.v`、`software/`、`ref/`、`asm2coe/` 或任何 `build/sim_out` 目录。

## 上板步骤

1. 用最新两份游戏 COE 更新 ROM_D 和 RAM_B，并重新生成 output products。
2. 检查顶层、Design Sources 和 `icf.xdc` 后生成 bitstream。
3. 连接 VGA 显示器和 PS/2 键盘，通过 Hardware Manager 下载。
4. 设置 `SW2=0`、`SW14=1`、`SW15=0`、`SW7:5=000`，然后复位。
5. 确认进入 `WATER SORT` 菜单，并依次检查三档布局、选关、倾倒、撤销、重开、返回菜单和通关提示。
6. 输入 0 或 13 以上应显示 `LEVEL INVALID`，不能开始。
7. 将 `SW14=0` 检查 VGA 色条与键盘方块；将 `SW15=1` 检查原始键盘扫描码。

若只显示空试管，先检查两份 COE 和 IP output products；若数码管能显示扫描码但游戏不响应，检查键盘中断版固件是否确实进入 ROM_D；若出现固定竖线，检查 RGB、HS、VS 是否仍统一经过 `vga_output_register`。

## 实现摘要

键盘和显示链路为：

```text
PS/2 -> 扫描码译码 -> 事件锁存 -> CPU 中断 -> C ISR
                                        |
                                        +-> 游戏状态 shadow/commit
                                                |
                                                +-> 帧边界 active 状态 -> VGA 实时渲染
```

键盘 `key_ready` 和计数器请求在顶层合并到 CPU 的单个 `INT`。trap 入口保存/恢复整数寄存器，C ISR 读取事件、更新游戏、提交画面并 ACK，主循环不轮询键盘。

CPU 只发布试管和 UI 状态；VGA 根据当前像素坐标实时绘制。`COMMIT` 先固定 pending 快照，再在下一 `frame_tick` 整体切换 active 状态，避免画面撕裂。最终 RGB、HS、VS 经过输出寄存器后连接管脚，避免组合译码毛刺。

## 开发日志

- Step 1：完成电脑端纯 C 游戏规则和测试。
- Step 2：完成键盘事件 MMIO、裸机启动、链接和双 COE 构建。
- Step 3：完成 CPU 到 VGA 的 shadow/commit 状态链路。
- Step 4：完成试管、液体、光标和选中状态渲染。
- Step 5：完成固定关卡的完整游戏固件与整机仿真。
- Step 6：完成三档难度、36 个 BFS 验证关卡、2048 步撤销、菜单和文字 UI。
- Step 7：将键盘输入改为机器模式中断；trap 保存/恢复现场并调用 C ISR，真实 SCPU 完整交互仿真通过。
- 最终整理：课程验收全部通过；移除阶段性诊断固件、旧备份模块和生成产物，统一交付文档与验证入口。

历史标签：`single-cycle-v1`、`pipeline-v1`、`interrupt-v1`。
