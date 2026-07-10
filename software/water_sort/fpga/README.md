# Water Sort FPGA 裸机固件

该目录提供 RV32I/ILP32 裸机启动、链接和双 COE 构建流程。默认构建 Step 6 完整游戏，并在进入 `main` 前运行 `isa_coverage.S`，覆盖 CPU 已实现的 37 条指令。

## 操作

启动进入菜单：

- 上下方向键或 W/S：EASY、NORMAL、HARD 循环切换。
- 左右方向键或 A/D：在当前难度的 12 个关卡间循环。
- 数字键：直接输入关卡号 `1～12`；Backspace 删除末位。
- Enter/Space：加载所选关卡并开始。

游戏中：左右/A/D 移动，Enter/Space 选择或倾倒，Esc 取消，U 撤销，R 重开当前关，M 返回菜单。数码管显示当前步数，LED 显示光标，通关后 LED 全亮。

## 构建

```bash
make
```

生成文件：

- `coe/water_sort_game_i.coe`：`ROM_D` 初始化。
- `coe/water_sort_game_d.coe`：`RAM_B` 初始化；当前包含关卡模板和十进制转换常量，不能继续使用旧的全零数据 COE。
- `build/water_sort_game_i.mem`、`build/water_sort_game_d.mem`：整机仿真镜像。
- `build/water_sort_game.asm`：37 指令覆盖与反汇编检查。

程序 `.text` 位于 `0x0000_0000`，`.rodata/.data/.bss` 和栈位于 `0x1000_0000～0x1000_0fff`。链接脚本会拒绝超过 4 KiB ROM 或侵占 512 字节保留栈的构建。

2026-07-10 多关卡构建结果：`.text` 2888 字节、`.rodata` 576 字节、`.bss` 2112 字节。真实 `SCPU` 整机仿真已通过非法关卡号拒绝、LEVEL 12、困难模式、倾倒、撤销、重开和返回菜单。
