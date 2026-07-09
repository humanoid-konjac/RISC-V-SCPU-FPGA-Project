# AGENTS.md

本文件给后续在本目录工作的代码代理使用。回复使用中文。

## 项目事实

- 顶层：`top.v`
- CPU RTL：`code/`
- 板级 IO：`IO/`
- 参考工程模块：`edf_file/`
- COE 文件：`coe/`
- 管脚约束：`icf.xdc`
- 当前 CPU：五级流水线 `SCPU`

`ref/`、`asm2coe/`、`asm2code/` 不进入版本控制。

## 当前正确连接

普通数据 RAM 通路必须是：

```text
SCPU Addr_out[11:2] -> RAM_B.addra
SCPU Data_out       -> dm_controller.Data_write
RAM_B.douta         -> dm_controller.Data_read_from_dm
dm_controller.Data_read -> SCPU.Data_in
dm_controller.Data_write_to_dm -> RAM_B.dina
dm_controller.wea_mem -> RAM_B.wea
```

不要恢复旧的 `MIO_BUS -> RAM` 通路。`MIO_BUS` 只用于外设译码、显示和外设读数据返回。

## 流水线与时钟约束

- `SCPU` 是 IF/ID、ID/EX、EX/MEM、MEM/WB 五级流水线。
- 数据冒险主要靠旁路解决：EX/MEM、MEM/WB 到 EX，WB 到 ID，store 写数据使用旁路后的 `rs2`。
- load-use 冒险插入 1 个 bubble。
- 控制冒险使用静态预测：`jal` taken；条件分支后跳 taken、前跳 not taken；`jalr` 在 EX 阶段重定向；预测错误 flush IF/ID 与 ID/EX。
- `RF` 下降沿写回，实例名必须保留为 `U_RF`。
- `SCPU.clk` 接板载 100MHz `clk`，流水线推进由 `SCPU.en` 控制。
- `top.v` 中 `cpu_en` 必须由实际 `Clk_CPU` 的上升沿检测生成，不要硬编码 `clkdiv[n]` 位。
- `clk_div.v` 可以调整 `Clk_CPU` 的分频位；调整后不应再同步修改 `top.v` 的 `cpu_en` 逻辑。
- `RAM_B.clka` 和 IO 写寄存器采样时钟保持接 `~clk`。

## IP 名称要求

- 指令 ROM 模块名：`ROM_D`
- 数据 RAM 模块名：`RAM_B`
- CPU 模块名：`SCPU`
- 访存控制模块名：`dm_controller`

`RAM_B` 需要 32 位数据、10 位地址、4 位字节写使能。

## 版本标记

- `single-cycle-v1`：流水线合并前的单周期版本。
- `pipeline-v1`：通过板上 `testac.coe` 的五级流水线版本。

## 修改原则

- 改 RTL 前先看当前端口名和实例名，不要按记忆改。
- 不要提交 Vivado 生成物、仿真输出、`ref/`、`asm2coe/`。
- `.coe` 只放在 `coe/`。
- 移动 `.coe` 后要提醒用户在 Vivado 中重新指定文件或重新生成 IP。

## 建议验证

能跑 `iverilog` 时，必须至少做顶层展开检查。若使用 Vivado IP，仿真环境需要对应 IP 仿真模型或 stub。
