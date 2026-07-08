# RISC-V SCPU FPGA Project

这是一个用于 Vivado 下板的单周期 RISC-V CPU 工程。当前版本使用自写 `SCPU` 和 `dm_controller`，保留了参考工程中可用的 IO/显示/总线模块。

## 目录结构

- `top.v`: FPGA 顶层，连接 CPU、ROM、RAM、外设总线、数码管、LED、按键和开关。
- `code/`: 自写 CPU RTL，包括控制器、ALU、寄存器堆、PC/NPC、立即数扩展、访存控制等。
- `IO/`: 板级 IO RTL，包括按键/开关输入处理、分频器、计数器。
- `edf_file/`: 当前仍在工程中使用的参考工程文件，包括 `MIO_BUS`、`Multi_8CH32`、`SSeg7`、`SPIO` 等 IO/显示/总线模块。
- `archive/`: 已从当前工程移出的旧参考文件，仅作备份归档，不参与综合、实现或仿真。
- `coe/`: Vivado ROM/RAM IP 初始化文件。
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

普通数据 RAM 访问不经过 `MIO_BUS`。`MIO_BUS` 只负责外设译码、显示相关数据和外设读数据返回。

## 存储器 IP 要求

指令 ROM：

- 模块名：`ROM_D`
- 地址：`a[9:0]`
- 数据输出：`spo[31:0]`

数据 RAM：

- 模块名：`RAM_B`
- 地址：`addra[9:0]`
- 时钟：`clka`
- 写数据：`dina[31:0]`
- 字节写使能：`wea[3:0]`
- 读数据：`douta[31:0]`

切换 `.coe` 后，需要重新生成对应 IP 的 output products，然后重新综合、实现、生成 bitstream。

## `dm_controller`

`dm_controller` 处理 CPU 的 load/store 访存格式：

- word：直接读写 32 位。
- halfword：按 `Addr_in[1]` 选择高/低 16 位，并做符号扩展。
- halfword unsigned：按 `Addr_in[1]` 选择高/低 16 位，并做零扩展。
- byte：按 `Addr_in[1:0]` 选择字节，并做符号扩展。
- byte unsigned：按 `Addr_in[1:0]` 选择字节，并做零扩展。

写内存时，`Data_write_to_dm` 负责把待写数据放到正确字节 lane，`wea_mem[3:0]` 负责只写对应字节。
