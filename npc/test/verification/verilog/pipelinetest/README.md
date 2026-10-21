# Chisel 流水线逐指令事件验证

本工程根据 `docs/verification/pipeline_chisel_formal_verification_plan.md` 搭建，沿用相邻 `pipelinetest` 的 `Makefile + verify.sby + pipelinetest.sv + build/` 组织方式。**本次交付是验证框架，不承诺当前 DUT 通过验证，不修改或重新生成工程外 RTL。**

- DUT：`vsrc/core/pipeline-chisel/riscv32e_core.v` 及其直接依赖。
- REF：`vsrc/core/single/riscv32e_core_sc.v` 及公共 GPR/CSR、译码和执行模块。
- 默认 `N=5`，两侧各自执行同一组独立生成的有限指令序列；并非用 DUT 写回反向生成 REF 输入。
- 逐指令记录并比较事件，而非逐周期对齐或仅比较最终寄存器快照。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `Makefile` | 配置生成、展开检查、BMC、进展、cover、自检入口 |
| `verify.sby` | ALU / MEM / 反压任务模板 |
| `configure.py` | 显式 RTL 清单、渲染配置、工具版本及 SHA-256 manifest |
| `pipelinetest.sv` | DUT/REF 连接、复位、IF 槽位队列、完成条件、cover |
| `pipeline_types.svh` | 每条指令的事件记录格式 |
| `instruction_sequence.sv` | 独立的符号指令槽与合法性约束 |
| `formal_env.sv` | 有界反压、单 outstanding 响应、请求稳定性、两侧符号内存 |
| `ref_monitor.sv` | 单周期执行快照及延后一拍的退休关联 |
| `dut_monitor.sv` | IF 返回顺序到退休顺序的关联、MEM 请求/响应日志 |
| `event_scoreboard.sv` | 按序号比较两侧每条已退休指令的事件 |
| `scoreboard_selftest.sv` / `selftest.sby` | 不依赖 DUT 的正向和故障注入自检 |

## 使用

需要 Python 3、Yosys（包含 `slang` 插件）、SymbiYosys 和 SMT solver。默认 solver 为 `boolector`，可改为已安装的 `yices` 或 `z3`。直接用传统 `read_verilog -sv` 不足以可靠读取当前 Chisel 生成的嵌套 packed struct / assignment pattern，工程使用 `plugin -i slang; read_slang --single-unit`，不转换或修补 DUT/REF 逻辑。公共头文件有未使用的 `EXPT_EXU_ILL()` 空参数宏声明，Slang/Icarus 拒绝其语法；配置器只在 `build/riscv32e_defines.v` 副本中将声明改为无参数宏，原始文件不变，且检查它确实没有被本任务 RTL 调用。REF 译码器中三处 `inst[high:low][0 +: width]` 也仅在 build 副本中等价展开为 `inst[low +: width]`；不改指令译码逻辑。上述兼容规则匹配不到预期源码就拒绝构建，原文件和副本的摘要都会记录。符号源显式定义为验证顶层环境输入：复位时锁存指令槽与初始内存，运行时保持指令序列不变；ready/响应延迟输入可每拍变化。这样不依赖 Slang 对 `anyconst/anyseq` 属性的版本支持，也绝不把未驱动 DUT 信号改成自由输入。

```sh
cd test/verification/verilog/pipelinetest-chisel
make help
make check                         # 完整前端展开与结构检查，不求解 DUT 正确性
make selftest                      # 比较器正例、覆盖以及预期失败的故障注入
make bmc                           # ALU 安全性质，默认深度 40
make progress                      # ALU 有界进展，必须完成，不能空轨迹 PASS
make cover                         # ALU 可达性
make verify                        # 上述三项一起运行
make mem                           # ALU + load/store，安全/进展/覆盖
make stall                         # ALU + load/store + IF/MEM 有界反压
make verify TASKS="mem_bmc stall_progress" N=5 SOLVER=boolector CPU_NUM=2
make report                        # 分别列出已完成任务的原始状态
make clean                         # 仅清理本工程内的 BUILD_PATH
```

也可以从其他目录使用 `make -C <工程目录> ...`，路径不依赖调用者的当前目录。

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `N` | 5 | 目标指令条数，必须大于零 |
| `DEPTH` | 40 | 安全性质 BMC 展开深度 |
| `CVR_DEPTH` | 120 | cover 深度；未命中不等同于安全性质失败 |
| `MAX_CYCLES` | 96 | 复位释放后允许的执行周期；进展任务深度自动为该值 + 8 |
| `MAX_WAIT` | 2 | stall 任务的环境 ready 等待和响应附加延迟上界 |
| `MEM_BYTES` | 16 | 符号内存字节数，至少 4 且为 4 的倍数 |
| `SOLVER` | boolector | 所有任务实际使用的 solver |
| `CPU_NUM` | 4 | SBY 并行任务数 |
| `BUILD_PATH` | build | 必须严格位于本工程内，可用相对或绝对路径 |
| `SELFTEST_DEPTH` | 16 | 比较器自检深度，至少 14，覆盖缺退休 deadline |

`build/verify_<任务>/` 保存 SBY 状态、日志和反例/覆盖轨迹；`build/selftest_<任务>/` 保存比较器自检结果。`build/manifest.json` 记录实际参数、工具版本、RTL/框架/配置摘要，生成配置自身也有摘要。每个 DUT 任务的 `src/manifest.json` 还保存启动时的清单快照。重新运行会更新 build 根 manifest 和对应任务目录，保留结果时应复制整份 build；汇总时以各任务 `config.sby` 和快照为准。SBY 输出的 `ERROR` / `UNKNOWN` 不能当作预期故障注入成功。

## 当前验证边界

### A：直线 ALU 和初始化

支持 RV32E 的 LUI、OP-IMM、OP 基本整数指令；排除 AUIPC、分支、JAL/JALR、RV32M、CSR、Trap、FENCE 和中断。OP/OP-IMM 的 funct7 和 x0–x15 编码受约束，允许写 x0，无架构写事件的指令仍必须退休。未从 DUT 输出选择或限制输入指令。

REF 的公共 `gprs` 没有清零复位，DUT GPR 初态不同。因此仅允许读取 x0 或被更早序列槽写过的寄存器，不假设两核内部初态相同、不直接灌寄存器。第一条指令自然只能从 x0 读取或执行 LUI。后续允许 RAW、连续写同一寄存器和 x0 操作；不限定 DUT 必须正确转发。

两侧在同一上升沿的更新前状态采样。REF 的 GPR 写事件是当周期组合输出，但 `inst_done` 延迟一拍且之后保持高；`ref_monitor` 保存每个执行沿快照，在下一拍验证 `inst_done` 并记为退休，避免漏掉第一条或把下一条写事件配给上一条。N 条执行之后仅给 REF NOP，不把后续 NOP 算入目标序列，且断言其没有额外副作用。

### B：MEM 模型和事务归属

MEM/stall 任务允许 LB/LH/LW/LBU/LHU、SB/SH/SW；所有地址限制为 `x0 + 非负立即数` 且落在小型符号内存中，半字/字自然对齐；即使扩大内存，指令仍只可访问 12 位有符号立即数的非负区间。地址约束来自独立指令编码，不假设 DUT 实际请求正确；DUT 的真实地址、op、store 有效位仍需断言和比较。

两侧从复位沿锁存的相同符号字节内存开始，之后分别按各自接受的 store 更新。REF 必须在执行周期获得已扩展的架构 load 值；其内存适配器提供零延迟完成，不能把 REF 当成可暂停的请求核。DUT 则获得锁存的对齐原始 32 位字，由 DUT 自己选择字节/半字并扩展。记录比较 load 原始数据，另通过 GPR 比较检查扩展结果。store 在请求握手时生效，并与 load 一样提供完成响应。

只支持 **in-order、每条指令至多一个事务、单 MEM outstanding**。请求归属由独立输入序列中下一个尚未发请求的 MEM 槽确定，不由当前退休周期或 DUT 请求地址猜测；响应归属由锁存的请求序号确定。请求须属于已经 IF 返回且尚未退休的槽。记录请求/响应计数，拒绝重复、无主响应、非访存指令的事务以及退休前未完成的事务。没有直接导出的退休指令码，指令身份保证依赖该直线、顺序接收/顺序退休契约；不宣称覆盖错误路径/flush 或乱序执行。

store 比较低 8/16/32 有效位，不比较无效高位；load 不比较无效写数据。所有完整字节地址和操作码都参与比较。MEM 未完成不能被当作无事件跳过。

### C：IF、反压和有界进展

复位固定为前三拍高，之后保持低，覆盖 `ResetPcGetter` 的复位链。无自由复位输入、无内部状态相等假设。IF 请求握手时保存槽序号与响应指令内容；响应不会读取新 PC 或新槽代替原请求。单 outstanding IF 允许旧响应消费与新请求同拍发生，以便覆盖连续退休。N 个请求之后停止服务，允许 DUT 保持额外的取指请求，但禁止额外退休或架构副作用。

PC 不参与两侧事件配对。DUT IF 地址另外断言为 `RESET_PC + 4*接收序号`，用来防止把错误取指地址喂成正确序列；这不是两侧 PC/dnpc 差分。IF/MEM 请求在反压期间的 valid 和 payload 必须稳定，这些是断言，不是环境假设。

stall 任务在请求持续有效时有界地拉高 ready，并对每次接受的响应选择 `0..MAX_WAIT` 额外等待；请求接受时锁存响应 payload，等待/反压期间保持不变。无无限不响应的环境。`*_bmc` 检查有限深度安全性，`*_progress` 独立在 deadline 断言完整完成；后者不会因为 DUT 永不退休而空通过。

完成条件是 REF/DUT 都恰好 N 条退休、N 条 IF 请求/响应完成、所有记录已按顺序比较、MEM 请求/响应计数相等且 outstanding 清空。完成后仍检查额外副作用，不提前终止安全检查。

### D/E：尚不支持

- 控制流 redirect/flush、被取消指令、旧 IF 响应重叠：不生成对应指令，也不设置伪 cover。
- CSR 和 Trap：记录结构及比较器预留完整字段，自检覆盖字段；当前集成任务断言两侧不会产生这些事件，**不宣称已实现 CSR/Trap 差分任务**。后续必须先建立初态与有效字段语义，不能仅开启指令约束。
- x0 不把 `wen && waddr==0` 视为 GPR 写事件；此外只读探测两核 x0 为零。`reference_core.m_gprs.x[0]` 和 `dut.m_gprs.x[0]` 是有意保留的层次路径依赖；没有用内部 WBU 信号替代 DUT 顶层正式写端口来掩盖接口缺陷。
- 安全检查、cover 和有限进展分别解释。cover 命中不代表正确性证明，BMC 不代表无界证明或全 ISA 证明。各项 cover 要求 N 条退休、连续退休、队列积压、RAW、连续同 rd、各 load/store；只在 stall 且 `MAX_WAIT>0` 时增加等待/反压 cover；`N=1` 时不生成需要至少两条退休的 cover。

## 当前 RTL 的已知接入限制

当前生成的 `riscv32e_core.v` 顶层 GPR/CSR/Trap 观测输出为常量，`Lsu.v` 的请求 op 也存在固定值。框架直接连这些生产接口，不改 DUT，不旁路为内部“看起来正确”的信号。因此 `make check` 成功只说明框架及 RTL 可被前端展开；实际 BMC 失败、进展失败或 cover 未达到是允许且需要保留的结果。具体结果以当前源文件摘要下的 SBY 日志为准，不复用相邻旧工程历史 PASS。

建议首次接入按 `make check` → `make selftest` → 小深度 `make bmc` 的顺序执行。若实际 DUT 验证失败，保存反例和 manifest；本工程搭建任务不要求现场修复 DUT。

## 框架搭建时的接入检查

以下仅记录本次本地接入结果，不是未来源码版本的验证结论；后续以任务内保存的源码摘要为准。

- 工具：Yosys `0.54+23`、SBY `v0.54`、Boolector `3.2.4`。
- `make check`：完整 DUT/REF/框架展开及 `check -assert` 通过，0 个结构问题。
- `make check N=1 MAX_WAIT=0 BUILD_PATH=build/boundary`：参数边界展开通过。
- `make selftest BUILD_PATH=build/selftest-run`：正向 BMC、cover 均 PASS；20 项故障注入均为预期断言 FAIL，无 ERROR/UNKNOWN。覆盖 GPR 数据/地址/使能、MEM 地址/op/有效写数据/原始读数据、CSR 地址/数据/使能、Trap 四字段/使能、序号、缺退休、缺请求/响应、额外事务。
- `make verify TASKS="alu_bmc mem_bmc stall_bmc" DEPTH=16 CPU_NUM=3`：三项均实际进入 solver 并生成反例；ALU 在 step 11 触发 GPR 使能/地址比较失败，MEM/stall 在 step 9 触发合法访存 op 断言失败。返回非零是实际 DUT 安全性质 FAIL，不是框架预期失败配置。
- 深度较大的 DUT 进展和 cover 任务提供入口，但未在本次接入验收中运行；没有声称其通过或不可达。
