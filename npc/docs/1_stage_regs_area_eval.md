# stage_regs 面积精简评估报告

- 日期：2026-10-01
- 综合结果：`build/yosys/area-hier/stat_hier.txt`（core 类型：pipeline，`riscv32e_core`，非 FORMAL_VERIFY 配置）
- 结论先行：**stage_regs 本体结构已相当精简，进一步压缩的空间主要在"字段级死重裁剪"（约 0.66k um²）和"数据寄存器去复位"（约 1.5~2.5k um²，需实验确认）；移除输出旁路 mux 几乎没有面积收益，不建议。**

## 1. 现状

stage_regs 是全 SoC 面积第一大的模块组，超过 exter_dev、xbar：

| 实例 | 级间边界 | 位宽 | 面积 (um²) | 时序单元占比 |
|---|---|---|---|---|
| ifu_regs | IF→ID | 133 | 1133.160 | 53.1% |
| idu_regs | ID→EX | 196 | 1669.416 | 53.1% |
| idu_gpr_regs | ID→EX (gpr×3) | 96 | 818.216 | 53.1% |
| exu_regs | EX→LS | 415 | 3533.544 | 53.1% |
| lsu_regs | LS→WB | 287 | 2444.008 | 53.1% |
| wbu_regs | WB→提交 | 102 | 869.288 | 53.1% |
| **合计** | | **1229** | **10467.632** | **5557.538 (53%)** |

- 占顶层 `ysyxSoCFull` 总面积 43110.62 um² 的 **24.28%**（`build/yosys/area-hier/area_hier.csv` 已将其归组为"流水线寄存器"）。
- 单位成本：**8.52 um²/bit = DFF 4.52 + 组合逻辑 4.00**。组合逻辑约占 4910 um²（47%），是绝对量第二大的可优化部分。

## 2. 结构分析（为什么组合逻辑占 47%）

`vsrc/core/common/stage_regs.v` 存储模式每 bit 的逻辑为：

```verilog
assign stage_bits = stage_done ? bits : r_bits;   // 输出旁路
always @(posedge clk)
    if (rst) r_bits <= 0;                          // 同步复位
    else if (stage_done) r_bits <= bits;           // 使能
```

综合后每 bit 恰好是 `DFF_X1 + AOI211_X1 + AOI21_X1 + INV_X1`（另加每实例 1 个共享 AND2 计算 valid&&ready）。注意：

- 输出旁路 mux、FF 的 D 端使能/复位 mux 三个逻辑锥已被 ABC 合并为同一套门，**"旁路 mux"并没有单独付费**；
- 单元列表是 DFF_X1 而非 DFFR_X1，说明同步复位被并入了 D 端数据 mux（3:1），而不是用复位 FF 实现。

## 3. 精简方案评估

### 方案 A：流水线总线死字段裁剪（推荐，低风险）

沿流水线传递的部分字段在下游已无任何功能消费（非 FORMAL 配置下核实）：

| 死字段 | 证据 | 占用位槽 | 预估节省 |
|---|---|---|---|
| `rs1/rs2` (各5b) | GPR 读口由译码器 `id_imm_rs1/2` 直接索引（riscv32e_core.v:985）；EX 体内不使用 rs1/rs2（execute.v 仅透传）；LSU 仅透传；WB 解包后丢弃（write_back.v:41） | 10b × 3 级 (idu/exu/lsu_regs) = 30 | ~256 um² |
| `inst` (32b) | LSU 非 FORMAL 输出不含 inst（load_store.v:85-98），核内 `con_ex_inst` 无消费者 | 32b × 1 级 (exu_regs) = 32 | ~273 um² |
| `inst_code` (16b) | WB 体内不使用 inst_code（write_back.v 仅解包），LS_OUT 之后的唯一消费者不存在 | 16b × 1 级 (lsu_regs) = 16 | ~136 um² |

- 合计 **78 位槽 ≈ 0.66k um²**（芯片的 1.5%，stage_regs 的 6.3%）。
- 做法：改 `execute.v`/`load_store.v`/`write_back.v` 的 pack/unpack 及 `riscv32e_core.v` 的 `EX_OUT/LS_OUT/WB_IN` 等 localparam；FORMAL_VERIFY 分支保留原字段（需在 `ifdef` 中兼容）。
- 不改任何时序行为，CPI 无影响，可通过 difftest 回归验证。

### 方案 B：数据 payload 寄存器去同步复位（中等风险，收益需实验确认）

stage_regs 的数据内容在 valid=0 时均为 don't-care（握手由 inner_con 的 valid 门控，消费点只在 stage_done 周期采样），`rst`/`core_flush_done` 清零 payload 并无功能必要。

- 去掉复位后 D 端从 3:1 mux 降为 2:1 mux，与输出旁路完全共享，每 bit 组合逻辑有望从 4.0 降至 ~2 um²：**约 1.5~2.5k um²**（stage_regs 的 15~24%）。
- 风险点：需全量审计 payload 的消费方（perf_monitor、trigger、monitor 打印等）确认无"invalid 期间读 payload"的角落；综合器实际映射结果需重新跑 yosys 确认（ABC 未必按理论最简映射）。

### 方案 C：移除输出旁路 mux（不推荐）

- 面积收益 ≈ 0：旁路与使能/复位逻辑已合并复用同一套门（见第 2 节），单独移除旁路省不下门。
- 反而破坏现握手约定（stall 期间靠旁路保持旧数据），需要重做 valid 打拍/握手逻辑，改变各级延迟，有 CPI 回退风险。如要做，动机应是时序而非面积。

### 方案 D：inst_code 压缩编码（可选）

`INST_CODE_W=16` 实际信息量约 5~6 bit，随 ID/EX/LS 三级传递（48 位槽）。改成紧凑二进制编码并在消费点译码，净收益约 0.2k um²，但要在多个模块加译码逻辑，性价比一般。

### 其他（无收益）

- `idu_regs` 与 `idu_gpr_regs` 控制信号完全相同，合并为一个 292b 寄存器：**面积不变**，仅减少实例数。
- DATA_STORAGE=0 直连模式：六级流水 payload 都必须打拍，不适用。

## 4. 结论与建议

1. DFF 本体 5558 um²（53%）是流水线状态本身，不可压缩；可动的约 4910 um² 组合逻辑里，大部分是使能/复位/旁路合并后的必要逻辑。
2. **先做方案 A**（死字段裁剪，~0.66k um²，零风险），其中 `inst` 和 `rs1/rs2` 两项占大头。
3. **方案 B 作为第二步**（潜在 ~1.5~2.5k um²，需先做消费者审计并重新综合验证实际映射）。
4. 方案 A+B 合计预计可削减 stage_regs 面积的 **20~30%**（芯片总面积的 ~5~7%），之后 stage_regs 基本达到结构最简。
5. 附带发现：WB 级 expt/cause/tval (69b) 在 STA 流程中仅服务于 `IN_YOSYS_STA` 的 global_pc 统计钩子（riscv32e_defines.v:499-510），真实芯片网表中属于仿真冗余，如 STA 流程允许挂空可再省 ~0.6k um²（不在 stage_regs 内，归 csrs/全局逻辑）。
