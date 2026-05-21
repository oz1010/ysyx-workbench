# CPU 流水线代码审查报告

**审查范围**：`vsrc/core/pipeline/` + `vsrc/core/common/`（流水线相关）
**审查日期**：2026-05-21
**参考文档**：`docs/0_architecture.md`

---

## 概览

| 严重度 | 问题数 |
|--------|--------|
| 🔴 严重（功能错误） | 5 |
| 🟠 高（行为错误） | 4 |
| 🟡 中（设计缺陷） | 5 |
| 🔵 低（质量/性能） | 6 |

---

## 🔴 严重问题（功能正确性错误）

### S1. IDU：FENCE 指令未解码

**文件**：`vsrc/core/pipeline/inst_decode.v:183`

```verilog
// 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_FENCE;
```

FENCE 指令被注释掉，所有 FENCE 指令将解码为 `INST_INVALID`，进而在 EXU 触发非法指令异常。但架构文档和 `vsrc/core/pipeline/load_store.v:140` 中均有 FENCE 处理逻辑：

```verilog
wire fence_enable = (inst_code==`INST_FENCE | inst_code==`INST_FENCE_I);
```

LSU 中的 `fence_enable` 永远不会为真（因为 `INST_FENCE` 永远不会从 IDU 传出），导致：
- 软件依赖 FENCE 的内存序保证**完全失效**
- 该路径成为死代码

**修复**：取消 `inst_decode.v:183` 注释。

---

### S2. IDU：四条 CSR 指令未解码

**文件**：`vsrc/core/pipeline/inst_decode.v:189-192`

```verilog
// 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRC;
// 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRWI;
// 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRSI;
// 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRCI;
```

CSRRC（CSR 位清除）、CSRRWI/CSRRSI/CSRRCI（立即数版本）均被注释掉，实际运行的 EXU 处理是：

```verilog
// execute.v:277-280
`INST_CSRRC:  `EXPT_RISE(`STAGE_INDEX_EXU, `EXPT_CAUSE_ILL, inst)
`INST_CSRRWI: `EXPT_RISE(`STAGE_INDEX_EXU, `EXPT_CAUSE_ILL, inst)
```

由于 IDU 将这些编码输出为 `INST_INVALID`，EXU 永远不会匹配上述 case，而是触发默认非法指令路径。任何使用这 4 条指令的程序（包括 RISC-V ABI 常见模式）均会异常终止。

**修复**：补全 4 条 casez 模式并补充正确的 opcode/funct3 编码：
- CSRRC：funct3=3'b011，opcode=7'b1110011
- CSRRWI：funct3=3'b101，opcode=7'b1110011
- CSRRSI：funct3=3'b110，opcode=7'b1110011
- CSRRCI：funct3=3'b111，opcode=7'b1110011

---

### S3. risk_control：FIFO 出队条件错误（分支预测检测逻辑 Bug）

**文件**：`vsrc/core/pipeline/risk_control.v:52-56`

```verilog
if (stage_valid[`STAGE_INDEX_EXU] & |fetch_infos[fetch_rindex]) begin
    fetch_infos[fetch_rindex] <= 0;
    fetch_rindex <= fetch_rindex + 1;
end
```

FIFO 的出队条件是「EXU 有有效指令且 FIFO 非空」，并非「EXU 当前处理的是跳转指令」。

**错误场景**：

```
周期 N:   IDU=Branch@A,  EXU=NOP@X
FIFO写入: {predicted_fetch_pc=B, id_pc=A}

周期 N+1: IDU=...,       EXU=NOP@X (仍在 EXU)
FIFO读:  EXU 有效 && FIFO 非空 → 出队 {B, A}，校验 B == NOP的dnpc?
```

NOP 的 dnpc 是 X+4，与预测的 B 对比，可能触发**误 flush**；或者正确分支的记录被 NOP 消费掉，导致真正的**分支误判漏检**。

**修复**：出队条件应加上 EXU 当前处理跳转指令的判断：

```verilog
if (stage_valid[`STAGE_INDEX_EXU] & 
    |fetch_infos[fetch_rindex] &
    (|(con_ex_inst_code & `INST_CODE_JUMP))) begin  // 加此条件
```

---

### S4. EXU：SLTI 指令符号比较错误

**文件**：`vsrc/core/pipeline/execute.v:252`

```verilog
`INST_SLTI: r_result <= {{31{1'b0}}, (s_src1 < imm)};
```

`s_src1` 是 `wire signed [31:0]`，但 `imm` 是 `wire [DATA_WIDTH-1:0]`（无符号）。Verilog 规则：有符号与无符号比较时，有符号操作数会被转换为无符号后比较，导致**负数立即数比较结果错误**。

例如：`slti x1, x2, -1`（imm=-1，符号扩展后=0xFFFFFFFF）
- 正确结果：若 x2 < -1（有符号），rd=1
- 实际结果：与 0xFFFFFFFF 无符号比较，几乎总是 0

**修复**：

```verilog
wire signed [31:0] s_imm = imm;
`INST_SLTI: r_result <= {{31{1'b0}}, (s_src1 < s_imm)};
```

---

### S5. MDR：多周期实现对 MULH 系列和有符号除法结果错误

**文件**：`vsrc/core/common/ex_muldivrem.v:240-243`（S_MUL 状态），`vsrc/core/common/ex_muldivrem.v:266`（S_DIV 状态）

**问题一：乘法结果固定取低 32 位**

```verilog
// S_MUL done:
result <= mul_res[31:0];  // 永远取低32位
```

MULH/MULHSU/MULHU 需要乘积的**高 32 位**（即 `mul_res[63:32]`），但 `ex_muldivrem_multi` 永远输出 `mul_res[31:0]`。`signed_mode` 在 S_MUL 状态被解码但从未使用，无符号移位加法也不能正确计算有符号乘法的高位。

**问题二：除法忽略符号模式**

```verilog
// S_DIV: 始终执行无符号恢复除法
if (remainder_next >= {1'b0, div_divisor}) begin
```

`INST_DIV`（有符号除法）和 `INST_REM`（有符号取余）的 `signed_mode=1` 被设置，但 S_DIV 从不对被除数/除数进行符号转换，结果与 `INST_DIVU`/`INST_REMU` 等同，**有符号除法结果错误**。

此外，仿真时 `single_result != multi_result` 校验对 MULH 系列必然报 `$error`（两者计算的位段不同）。

**修复**：
1. S_MUL 末尾根据 `inst_code` 选择 `mul_res[31:0]` 或 `mul_res[63:32]`
2. 为有符号乘法补充两补数预处理（取绝对值 + 最终修正符号）
3. S_DIV 对 `signed_mode=1` 的情况，先转换为绝对值运算，最后修正商和余数的符号

---

## 🟠 高严重度问题（行为错误）

### H1. EXU：ECALL/MRET 未更新 mstatus

**文件**：`vsrc/core/pipeline/execute.v:166-183`

ECALL 写 mepc 和 mcause，MRET 读 mepc 跳转，但两者均未操作 `mstatus`：

| 操作 | 应更新字段 | 当前实现 |
|------|-----------|---------|
| ECALL | `mstatus.MPP←当前特权级`, `mstatus.MIE←0` | 未实现 |
| MRET | `mstatus.MIE←mstatus.MPIE`, `mstatus.MPIE←1` | 未实现 |

这导致：
- 多次 ECALL 嵌套时中断使能状态不正确
- MRET 返回后 MIE 不会恢复，后续中断可能被错误屏蔽

**当前缓解**：系统只支持 M 模式，且未实现硬件中断响应，所以实际影响有限，但会在差分测试中与 NEMU/QEMU 产生状态分歧。

---

### H2. 流水线中 CSR RAW 冒险未检测

**文件**：`vsrc/core/pipeline/risk_raw.v`（整体），`vsrc/core/pipeline/riscv32e_core.v:374-398`

`risk_raw` 只检测 GPR 的 RAW 相关（rs1/rs2 vs rd），对 CSR 操作完全不处理。

**危险场景**：

```asm
csrw mtvec, x1       # EXU/LSU 阶段写 mtvec
csrr x2, mtvec       # IDU 阶段读 mtvec → 读取旧值
```

CSR 读（`csrs.rdata`）是组合逻辑，CSR 写（来自 WBU 的 `csr_wch`）是同步写（下一 posedge 生效）。在高频使用 CSR 的初始化代码或 OS 中断处理中，连续 CSR 读写序列会得到错误的中间值。

**修复方向**：在 `risk_raw` 中增加 CSR 相关冒险检测，或在 WBU 到 EXU 增加 CSR 写前转发路径。

---

### H3. WBU：异常处理无硬件 Trap 机制

**文件**：`vsrc/core/pipeline/write_back.v:83-88`

```verilog
if (|expt) begin
    case (expt_cause)
        `EXPT_CAUSE_ILL: func_invalid_inst(pc, expt_tval); // DPI-C调用
        default: ;
    endcase
end
```

异常处理仅调用 DPI-C 函数 `func_invalid_inst`，该函数在仿真中直接终止模拟器。硬件应该：
1. 将 PC 写入 mepc
2. 写 mcause
3. 更新 mstatus
4. 跳转到 mtvec 指向的 trap handler

目前只有 EXU 的 ECALL 路径有部分 CSR 写（mepc/mcause），其他异常（非法指令、访存错误等）在 WBU 都是直接终止仿真，不走 RISC-V 规范的异常处理流程。

---

### H4. IFU：flush 期间 in-flight AXI 读未取消

**文件**：`vsrc/core/pipeline/inst_fetch.v:99-109`

当流水线 flush 触发时，IFU 的 `r_read_en` 不会被清除。已发送的 AXI 读事务会继续完成，设置 `r_stage_out_valid = 1`，将错误地址的指令写入 `r_read_inst`。

虽然下游的 `con_if_valid` 在 flush 期间被 `core_stage_flush[IDU]` 屏蔽，stale 数据最终会被正确丢弃，但：
1. **浪费 AXI 总线带宽**：ICache 需要完成对错误地址的读取
2. 如果 ICache miss，此笔读会导致一次额外的 DRAM 访问

**修复**：在 flush 信号有效时强制清零 `r_read_en`（需将 `core_stage_flush[IFU]` 引入 IFU 内部）。

---

## 🟡 中严重度问题（设计缺陷）

### M1. LSU：test_mode 路径双重赋值逻辑矛盾

**文件**：`vsrc/core/pipeline/load_store.v:241-245`

```verilog
`ifndef IN_YOSYS_STA
end else if (test_mode_enable) begin
    r_stage_out_valid <= stage_in_done ? 1 : 0;
    r_result <= func_test_intf({31'h0,write_inst}, access_addr, 4, src2); // 第一次赋值
    r_result <= 0;  // 第二次赋值，覆盖第一次
    r_result_update_gpr <= 0;
```

两条 `r_result <=` 非阻塞赋值连续出现，Verilog 语义下后者覆盖前者，`func_test_intf` 的返回值被**丢弃**。功能调用有副作用（初始化 Flash/PSRAM），但返回值无效，逻辑可能是未完成的实现。

---

### M2. risk_control：FLUSH_EX_BIT 未实现，异常 flush 缺失

**文件**：`vsrc/core/pipeline/risk_control.v:64-66`

```verilog
/* TODO 当跳转执行到EXU时，最早发现异常正好是LSU，优先处理异常即可。*/
if (|stage_exception) begin
    // 空实现
end
```

`stage_exception` 输入在顶层写死为 0（`riscv32e_core.v:841`：`.stage_exception(0)`），`FLUSH_EX_BIT` 从未被设置。这意味着：
- 所有异常（指令非法、访存错误）无法触发流水线 flush
- 异常后的管道冲洗依赖 WBU 的 DPI-C 调用直接终止仿真，不走正常流水

---

### M3. IDU：inst_code 为 reg 但驱动于组合逻辑块

**文件**：`vsrc/core/pipeline/inst_decode.v:49`

```verilog
reg [`INST_CODE_W-1:0] inst_code;

always @(*) begin
    inst_code = `INST_INVALID;
    casez(inst)
        ...
    endcase
end
```

`always @(*)` 驱动一个 `reg` 类型，实际推断为组合逻辑。这在仿真中正确，但综合工具可能给出 latch 推断警告，降低综合质量，且语义不如 `wire + assign` 清晰。

---

### M4. EXU：SRAI/SRA 算术右移手工实现，存在边界风险

**文件**：`vsrc/core/pipeline/execute.v:260,268`

```verilog
`INST_SRAI: ... r_result <= (src1 >> (imm&32'h1F)) | 
    ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))));
```

当移位量为 0 时：`32'hFFFFFFFF << 32`。Verilog 对 32 位值左移 32 位，结果为 0（行为正确），但此逻辑依赖位宽隐式截断，移植性差。建议改为：

```verilog
`INST_SRAI: r_result <= $signed(src1) >>> (imm & 32'h1F);
`INST_SRA:  r_result <= $signed(src1) >>> (src2 & 32'h1F);
```

---

### M5. risk_raw：Load-Use 冒险等待周期过多

**文件**：`vsrc/core/pipeline/risk_raw.v:44-50`

Load 指令（LW 等）的结果在 LSU 阶段结束时才可用。`risk_raw` 检测到 RAW 冒险后等待到 WBU 提交（`wb_pc == stage_wait_pc`），然后再经过两个时钟才释放 IDU。

实际上，Load 结果在 LSU 输出时即可前向传播至 EXU（Load-Use forwarding），完全不需要等到 WBU。当前实现对 Load 指令引入不必要的 **2 周期额外气泡**，降低了 CPI。

---

## 🔵 低严重度问题（代码质量/性能）

### L1. IFU：AXI 写通道 bready 固定为 0

**文件**：`vsrc/core/pipeline/inst_fetch.v:96`

```verilog
assign bready = 0;
```

IFU 从不发起写事务（awvalid=0），因此写响应（B 通道）永远不会到来，`bready=0` 在实践中无害，但从 AXI4 规范角度，Slave 如果发出了 bvalid（即使因错误路由），Master 永远不会接受，可能导致 Slave 死锁。建议改为组合拉高或保持 `bready=1`。

---

### L2. GPRs：x0 写使能路径为死逻辑

**文件**：`vsrc/core/common/gprs.v:72-75`

```verilog
wire [`RISCV_GPR_COUNT-1:0] wen_onehot;
assign wen_onehot = wen ? (1 << windex) : 0;
assign x[0] = 0;  // wire 直连 0
// for 循环从 i=1 开始，x[0] 的 wen_onehot[0] 未被使用
```

`wen_onehot[0]` 被计算但从不驱动任何寄存器，综合工具会将其优化掉，但仍产生静态警告。

---

### L3. CSRs：只读寄存器实现方式不利于综合

**文件**：`vsrc/core/common/csrs.v:77-79`

```verilog
assign csrs[func_get_csr_index(`CSR_MVENDORID)] = csr_mvendorid_data;
assign csrs[func_get_csr_index(`CSR_MARCHID)]   = csr_marchid_data;
```

`csrs` 是 `reg` 数组，对部分元素使用 `assign`（连续赋值）而其他元素由 `always` 驱动，形成混合驱动。某些综合工具对此处理不一致，且 `func_get_csr_index` 在综合路径中被调用（函数参数为运行时值），可能不被全部综合器正确内联。推荐只读 CSR 使用独立的 `wire` 并在读多路器中处理。

---

### L4. perf_monitor：指令计数以 IF 级为准，不反映退休数

**文件**：`vsrc/core/pipeline/perf_monitor.v:41-44`

```verilog
if (!last_if_valid && if_valid) begin
    func_cpu_stat_ctrl(`HW_CPU_STAT_INST, pc);
end
```

`HW_CPU_STAT_INST` 在 IFU 输出有效时递增，包含了所有被 flush 的 bubble 指令。实际 IPC 应以 WBU 退休为准（架构文档第 13 节说明了计数器含义，与实现不符）。

---

### L5. static_predictor：始终预测顺序执行

**文件**：`vsrc/core/pipeline/static_predictor.v:16-24`

```verilog
fetch_pc <= flush_type[`FLUSH_JUMP_BIT] ? dnpc :
            fetch_en ? fetch_pc + 4 : fetch_pc;
```

预测策略为「静态预测不跳转（predict not taken）」，所有跳转指令均引发 3 周期惩罚（IFU+IDU 被 flush，等待 EXU 确认目标后重新取指）。

对于循环（向后跳转通常 taken）和无条件跳转，性能损失显著。可考虑：
- 静态分支预测改进：向后分支预测 taken，向前预测 not taken
- 增加 BTB（Branch Target Buffer）

---

### L6. WBU：out_ready 路径未检查异常

**文件**：`vsrc/core/pipeline/write_back.v:78-90`

```verilog
always @(posedge clk) begin
    if (rst) begin
        r_stage_out_valid <= 0;
    end else begin
        r_stage_out_valid <= stage_in_done ? 1 : 0;
        if (|expt) begin
            case (expt_cause)
                `EXPT_CAUSE_ILL: func_invalid_inst(pc, expt_tval);
                default: ;
            endcase
        end
    end
end
```

`r_stage_out_valid` 无论是否有异常均设为 1，导致 WBU 在调用 `func_invalid_inst`（终止仿真）的同时向 core 输出 valid=1，表示「指令已提交」。一旦异常处理改为继续执行（trap handler 模式），此处需要对异常指令不更新 GPR 和 PC 的逻辑做严格区分。

---

## 附录：各模块关键问题汇总

| 模块 | 文件 | 关键问题 |
|------|------|---------|
| IFU | `inst_fetch.v` | H4（AXI未取消），L1（bready=0） |
| IDU | `inst_decode.v` | S1（FENCE），S2（4条CSR指令） |
| EXU | `execute.v` | S4（SLTI），H1（mstatus），H2（CSR RAW），M4（SRAI） |
| MDR | `ex_muldivrem.v` | S5（MULH/有符号除法错误） |
| LSU | `load_store.v` | M1（双重赋值），M5（Load-Use惩罚） |
| WBU | `write_back.v` | H3（无硬件Trap），M3（异常无flush），L6 |
| risk_raw | `risk_raw.v` | H2（CSR冒险），M5（Load-Use惩罚） |
| risk_control | `risk_control.v` | S3（FIFO出队逻辑），M2（FLUSH_EX未实现） |
| static_predictor | `static_predictor.v` | L5（固定预测不跳转） |
| GPRs | `gprs.v` | L2（死逻辑） |
| CSRs | `csrs.v` | L3（混合驱动） |
| stage_regs | `stage_regs.v` | 无显著问题 |
| inner_con | `inner_con.v` | 无显著问题 |
| perf_monitor | `perf_monitor.v` | L4（计数时机不准确） |

---

## 优先修复建议

按影响范围和修复代价排序：

1. **立即修复**：S1、S2 — 取消注释，5分钟内可修复，影响范围广（任何使用 FENCE 和 CSRRC/I 的程序）
2. **高优先**：S3 — risk_control FIFO 出队条件，添加一个 `inst_code` 判断即可
3. **高优先**：S4 — SLTI 有符号比较，一行修复
4. **计划内**：S5 — MDR 有符号乘除，需要重写 multi 版本的乘除状态机
5. **计划内**：H1、H3 — mstatus 更新和硬件 Trap，需要设计完整的异常处理路径
6. **长期优化**：M5（Load-Use forwarding）、L5（分支预测改进）
