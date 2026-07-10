# Step 2/3 裸机诊断固件

该目录提供 RV32I/ILP32 裸机启动、链接和双 COE 构建流程，以及用于验证“PS/2 -> MMIO -> CPU -> MMIO -> VGA”链路的 Step 3 固件。

固件启动后把中央色块设为红色。左方向键或 A 反向切换六种颜色，右方向键或 D 正向切换，R 恢复红色；每个逻辑键码同时写入 LED 和数码管。Enter/Space、Esc 在本阶段只用于验证按键码。

## 构建

安装 GNU RISC-V 裸机工具链后执行：

```bash
make
```

生成文件：

- `coe/game_phase3_i.coe`：加载到 `ROM_D`。
- `coe/game_phase3_d.coe`：加载到 `RAM_B`。
- `build/game_phase3.asm`：检查实际 RV32I 指令。

程序的 `.text` 位于 `0x0000_0000`，数据和栈位于 `0x1000_0000～0x1000_0FFF`，并为向下增长的栈至少保留 512 字节。链接脚本会在指令超过 4 KiB 或数据侵占保留栈空间时失败。

当前开发机没有安装 `riscv64-unknown-elf-*`，因此仓库不包含未经验证的预生成 Step 3 COE。请在安装工具链后本地执行 `make`，再按项目根目录 `README.md` 的“Step 2/3 上板测试”更新 Vivado IP。
