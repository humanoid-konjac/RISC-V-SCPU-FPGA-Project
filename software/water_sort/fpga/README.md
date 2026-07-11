# Water Sort FPGA 裸机固件

本目录把可移植游戏核心构建为 RV32I/ILP32 裸机程序。最终版本使用键盘机器模式中断：`trap_entry` 保存现场并调用 `keyboard_interrupt_handler`，处理完成后以 `mret` 返回，主循环不轮询键盘。

## 构建

需要 `riscv64-unknown-elf-*` 工具链：

```bash
make
```

如工具链前缀不同：

```bash
make CROSS=riscv32-unknown-elf-
```

输出：

- `../../../coe/water_sort_game_i.coe`：ROM_D 初始化。
- `../../../coe/water_sort_game_d.coe`：RAM_B 初始化，包含 36 关目录。
- `build/water_sort_game_i.mem`、`water_sort_game_d.mem`：整机仿真镜像。
- `build/water_sort_game.asm`：反汇编。
- `build/water_sort_game.map`：链接布局。

`.text` 位于 `0x00000000`；`.rodata/.data/.bss` 和栈位于 `0x10000000～0x10000fff`。链接脚本限制 ROM/RAM 各 4 KiB，并保留至少 512 字节栈。

最终构建尺寸：`.text` 3204 字节、`.rodata` 576 字节、`.bss` 2112 字节。启动时先设置栈、清零 `.bss`、运行 37 指令覆盖例程，再进入游戏并开启键盘中断。

## 上板

在 Vivado 中分别为 `ROM_D` 和 `RAM_B` 选择两份最新 COE，重新生成 output products，然后重新生成 bitstream。不要使用旧课程测试 COE，也不需要重新创建 IP。

操作方式和完整 Vivado source set 见仓库根目录 `README.md`。

## 已验证行为

真实 SCPU 整机仿真已覆盖：键盘中断进入、非法关卡拒绝、输入 LEVEL 12、切换困难模式、合法倾倒、撤销、重开和返回菜单；完整游戏已通过课程上板验收。
