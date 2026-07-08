# AGENTS.md

本文件给后续在本目录工作的代码代理使用。回复使用中文。

## 项目事实

- 顶层：`top.v`
- CPU RTL：`code/`
- 板级 IO：`IO/`
- 参考工程模块：`edf_file/`
- COE 文件：`coe/`
- 管脚约束：`icf.xdc`

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

## IP 名称要求

- 指令 ROM 模块名：`ROM_D`
- 数据 RAM 模块名：`RAM_B`
- CPU 模块名：`SCPU`
- 访存控制模块名：`dm_controller`

`RAM_B` 需要 32 位数据、10 位地址、4 位字节写使能。

## 修改原则

- 改 RTL 前先看当前端口名和实例名，不要按记忆改。
- 不要提交 Vivado 生成物、仿真输出、`ref/`、`asm2coe/`。
- `.coe` 只放在 `coe/`。
- 移动 `.coe` 后要提醒用户在 Vivado 中重新指定文件或重新生成 IP。

## 建议验证

能跑 `iverilog` 时，必须至少做顶层展开检查。若使用 Vivado IP，仿真环境需要对应 IP 仿真模型或 stub。
