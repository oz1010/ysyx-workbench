# NPC 架构文档

## 1. 项目概述

**YSYX-NPC**（一生一芯 Network Processor Core）是一个完整的 RISC-V 32 位处理器设计与仿真框架，包含：

- **硬件实现**：Verilog 编写的五级流水线 CPU（`vsrc/`）
- **软件仿真器**：C++ 编写的解释执行引擎（`src/`）
- **SoC 集成**：完整外设系统（`../ysyxSoC/`）
- **验证框架**：差分测试、指令追踪、性能监控

| 属性       | 值                    |
| ---------- | --------------------- |
| ISA        | RISC-V RV32I + M 扩展 |
| 数据位宽   | 32 位                 |
| 地址位宽   | 32 位                 |
| 流水线级数 | 5 级                  |
| 总线协议   | AXI4                  |
| 特权级     | Machine 模式          |

---

## 2. 顶层架构

```
┌─────────────────────────────────────────────────────────────┐
│                      riscv32e_core                          │
│                                                             │
│  ┌──────────────────────── Pipeline ─────────────────────┐  │
│  │  IFU → IDU → EXU → LSU → WBU                         │  │
│  │   ↓     ↓     ↓     ↓     ↓                          │  │
│  │  stage_regs (流水线寄存器，支持 flush)                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌── 寄存器文件 ──┐  ┌── 冒险控制 ────────────────────────┐  │
│  │ GPRs (32×32b) │  │ risk_raw (RAW 冒险)               │  │
│  │ CSRs (4096)   │  │ risk_control (控制冒险 + Flush)    │  │
│  └───────────────┘  │ static_predictor (静态分支预测)    │  │
│                     └──────────────────────────────────┘  │
│                                                             │
│  ┌── Cache ────────────────────────────────────────────┐  │
│  │  IFU ─(req-resp)─ ICache ─(AXI4)─┐                   │  │
│  │                                  ├─ arbiter_axi4 ─ xbar_axi4 │
│  │  LSU ─(req-resp)─ DCache ─(AXI4)─┘       ↓           ↓     │
│  └─────────────────────────────────── CLINT  exter_dev  io_master │
│                                                   (外部 SoC) │
│  ┌── 片内设备 ─────────────────────────────────────────┐  │
│  │  perf_monitor (性能监控计数器)                        │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. CPU 流水线

### 3.1 五级流水线总览

```
取指 (IFU) → 译码 (IDU) → 执行 (EXU) → 访存 (LSU) → 回写 (WBU)
  ↓              ↓              ↓              ↓              ↓
ifu_regs      idu_regs      exu_regs      lsu_regs      wbu_regs
              idu_gpr_regs
```

流水线采用 **valid-ready 握手协议**控制各级数据流动。每级之间用 `stage_regs` 寄存器隔离，支持同步 flush（冒险清空）。

### 3.2 IFU — 取指单元

**文件**：`vsrc/core/pipeline/inst_fetch.v`

- 接收来自 `static_predictor` 的预测取指 PC（`core_fetch_pc`）
- 通过 req-resp 主接口从 ICache 读取 32 位指令
- 将（PC, 指令, 异常信息）打包输出到 IDU
- FENCE.I 执行时，由顶层复位 ICache（`rst || fence_enable_trigger`）

**输出总线宽度**：`IF_OUT_DATA_W = ADDR_WIDTH + INST_WIDTH + STAGE_COUNT + DATA_WIDTH×2`

### 3.3 IDU — 译码单元

**文件**：`vsrc/core/pipeline/inst_decode.v`

- 解码 32 位 RISC-V 指令，识别指令格式（R/I/S/B/U/J）
- 提取字段：rd, rs1, rs2, 立即数, 指令码（16-bit `inst_code`）
- 同步从 GPRs 读取 rs1/rs2/a0 数据（寄存于 `idu_gpr_regs`）
- CSR 读地址在 IDU 阶段确定并同步读出

**输出总线宽度**：`ID_OUT_DATA_W = INST_WIDTH×3 + 5+5+5 + INST_CODE_W + STAGE_COUNT + DATA_WIDTH×2`

### 3.4 EXU — 执行单元

**文件**：`vsrc/core/pipeline/execute.v`

- 执行 ALU 运算（加减、逻辑、移位、比较）
- 调用 MDR 单元执行乘除余（RV32M）
- 计算跳转/分支目标地址 `dnpc`
- 处理 CSR 读写（CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI）
- 处理 ECALL/MRET 特权指令
- 生成 CSR 写通道信息（`csr_wch`）传递到 WBU

**输出总线宽度**：`EX_OUT_DATA_W = 5 + INST_CODE_W + INST_WIDTH×7 + 1 + STAGE_COUNT + DATA_WIDTH×2 + 5×2 + CSR_WCH_W`

### 3.5 LSU — 访存单元

**文件**：`vsrc/core/pipeline/load_store.v`

- 通过 req-resp 主接口执行 Load/Store 操作
- 支持非对齐访问（跨 4 字节边界时自动拆分为两次单字请求）
- 处理 LB/LH/LW/LBU/LHU（符号/零扩展）和 SB/SH/SW
- 无需访存的指令直接透传结果

**输出总线宽度**：`LS_OUT_DATA_W = INST_WIDTH×3 + 5 + 1 + INST_CODE_W + STAGE_COUNT + DATA_WIDTH×2 + 5×2 + CSR_WCH_W`

### 3.6 WBU — 回写单元

**文件**：`vsrc/core/pipeline/write_back.v`

- 向 GPRs 写入运算结果（`gpr_wen`, `gpr_windex`, `gpr_wdata`）
- 将 EXU 生成的 `csr_wch` 写入 CSRs
- 输出最终 `dnpc` 更新 `core_pc`

**输出总线宽度**：`WB_OUT_DATA_W = INST_WIDTH×2 + 5`

---

## 4. 寄存器文件

### 4.1 GPRs — 通用寄存器

**文件**：`vsrc/core/common/gprs.v`

- 32 个 32 位寄存器（x0～x31），x0 硬连接为 0
- 双读端口（rs1, rs2）+ 1 个写端口
- 额外读出 a0（x10）用于系统调用返回值

### 4.2 CSRs — 控制状态寄存器

**文件**：`vsrc/core/common/csrs.v`

支持的寄存器：

| CSR 地址 | 名称      | 说明                            |
| -------- | --------- | ------------------------------- |
| `0x300`  | mstatus   | 处理器状态                      |
| `0x305`  | mtvec     | Trap 处理程序基地址             |
| `0x341`  | mepc      | 触发异常的 PC                   |
| `0x342`  | mcause    | 异常原因                        |
| `0xf11`  | mvendorid | 厂商 ID（0x79737978 = "ysyx"）  |
| `0xf12`  | marchid   | 架构 ID（学号 23060295 十进制） |

- 同时支持 2 个 CSR 写通道（`CSR_WCH_ITEM_COUNT = 2`）
- 写通道宽度：`CSR_WCH_W = (1 + 12 + 32) × 2`

---

## 5. 冒险控制

### 5.1 RAW 数据冒险

**文件**：`vsrc/core/pipeline/risk_raw.v`

- 检测 IDU 阶段读取的 rs1/rs2 是否与 EXU、LSU、WBU 阶段的 rd 冲突
- 产生 `core_raw_wait` 信号，暂停 IDU 及之前各级（IFU 同时暂停）
- 暂停时 EXU/LSU/WBU 继续执行（drain pipeline）

### 5.2 控制冒险

**文件**：`vsrc/core/pipeline/risk_control.v`

- 检测跳转/分支指令（`INST_CODE_JUMP` 类）
- 产生 `flush_type` 和 `core_stage_flush`，清空对应流水线寄存器

Flush 类型（2 位）：

| 位   | 名称       | 触发条件                 |
| ---- | ---------- | ------------------------ |
| 0    | FLUSH_EX   | EXU 检测到分支需要 flush |
| 1    | FLUSH_JUMP | 无条件跳转 flush         |

### 5.3 静态分支预测

**文件**：`vsrc/core/pipeline/static_predictor.v`

- 根据当前 `core_pc` 和 `flush_type` 预测下一个取指地址 `core_fetch_pc`
- 分支误预测后，WBU 提供正确 `dnpc` 进行纠正

---

## 6. Cache 架构

### 6.1 ICache — 指令缓存

**文件**：`vsrc/core/pipeline/icache.v`

| 参数 | 含义                         | 默认值                           |
| ---- | ---------------------------- | -------------------------------- |
| W    | 组数 log₂                    | 配置项 CONFIG_ICACHE_PARAMETER_W |
| N    | 路数 log₂                    | 配置项 CONFIG_ICACHE_PARAMETER_N |
| M    | Cache Line 大小 log₂（字节） | 配置项 CONFIG_ICACHE_PARAMETER_M |

- 与 IFU 之间为 req-resp Slave 接口（CPU 侧）
- 与总线仲裁器之间为 AXI4 Master 接口（内存侧）
- 可缓存地址的读请求查表命中直接返回，未命中时通过 AXI4 从内存填充整行
- 不可缓存地址（片内 SRAM 等）的读写请求直接透传到 AXI4 总线
- FENCE.I 执行时通过顶层 `rst` 信号清空整个 ICache（方案 3）

### 6.2 DCache — 数据缓存

**文件**：`vsrc/core/pipeline/dcache.v`

- 参数配置同 ICache（独立的 CONFIG_DCACHE_PARAMETER_*）
- 与 LSU 之间为 req-resp Slave 接口
- 与总线仲裁器之间为 AXI4 Master 接口
- 只缓存读数据；写请求透传到 AXI4 总线，若写命中 cache 行则将其无效

### 6.2.1 req-resp 接口定义

IFU/LSU 与 ICache/DCache 之间采用 req-resp 类总线接口：

| 通道 | 信号                              | 方向（master → slave） | 含义                     |
| ---- | --------------------------------- | ---------------------- | ------------------------ |
| req  | `req_valid` / `req_ready`         | master → slave         | 请求握手                 |
| req  | `req_addr`                        | master → slave         | 访存地址                 |
| req  | `req_is_write`                    | master → slave         | 写请求标志               |
| req  | `req_wdata` / `req_wstrb`         | master → slave         | 写数据与字节使能         |
| resp | `resp_valid` / `resp_ready`       | slave → master         | 响应握手                 |
| resp | `resp_data`                       | slave → master         | 读数据（写响应数据无效） |

协议约定：读请求返回地址所在的对齐 32 位字，跨字的非对齐访问由 master（LSU）拆分为
两个单字请求并自行拼接；写请求以 `req_wstrb` 指示有效字节。形式化验证时由
`req_resp2axi4` 桥接模块（`vsrc/core/common/req_resp2axi4.v`）将 req-resp 转换为
AXI4 直连仲裁器。

### 6.3 Cache 公共组件

**文件**：`vsrc/core/common/cache.v`, `cache_block.v`, `cache_line.v`

---

## 7. 总线架构

### 7.1 AXI4 信号定义

| 参数           | 值    |
| -------------- | ----- |
| 地址位宽       | 32 位 |
| 数据位宽       | 32 位 |
| ID 位宽        | 4 位  |
| Burst 长度位宽 | 8 位  |

AXI4 ID 分配：

| ID   | 单元                  |
| ---- | --------------------- |
| 0x1  | IFU（透传读）         |
| 0x4  | LSU（透传写/读）      |
| 0x6  | ICache（行填充）      |
| 0x7  | DCache（行填充）      |

### 7.2 AXI4 仲裁器

**文件**：`vsrc/device/arbiter_axi4.v`

- 2 个 Master（ICache 和 DCache）合并为 1 个 Master 输出
- 使用轮询或优先级仲裁
- 仲裁器依据 `araddr/awaddr` 非零选择 master，并将下游响应回送给被选中的
  master；因此各 master 在一次事务完成前（含等待响应期间）必须保持地址非零

```
ICache ──┐
         ├── arbiter_axi4 ──► xbar_axi4
DCache ──┘
```

### 7.3 AXI4 交叉开关

**文件**：`vsrc/device/xbar_axi4.v`

- 1 个 Master 输入，3 个 Slave 输出
- 地址范围解码：

| Slave 序号 | 地址范围                    | 设备                       |
| ---------- | --------------------------- | -------------------------- |
| 0          | `0x0200_0000 ~ 0x0200_ffff` | CLINT                      |
| 1          | `0x2200_0000 ~ 0x2200_0fff` | exter_dev（VGA 控制器等）  |
| 2          | `0x0000_0004 ~ 0xffff_ffff` | io_master（外部 SoC/MMIO） |

---

## 8. 片内设备

### 8.1 CLINT — 核心本地中断控制器

**文件**：`vsrc/device/clint.v`

- AXI4 Slave 接口，地址 `0x0200_0000 ~ 0x0200_ffff`
- 提供 mtime / mtimecmp 寄存器
- 产生定时器中断（Machine Timer Interrupt）

### 8.2 exter_dev — 外部设备代理

**文件**：`vsrc/device/exter_dev.v`

- AXI4 Slave 接口，地址 `0x2200_0000 ~ 0x2200_0fff`（VGA 控制寄存器区域）
- 代理访问 NVBoard 等板级外设

---

## 9. SoC 外设系统（ysyxSoC）

**文件**：`../ysyxSoC/`（`build/` 中的生成文件和 `perip/` 中的外设实现）

完整 SoC 集成的外设列表：

| 外设         | 文件               | 总线 |
| ------------ | ------------------ | ---- |
| GPIO         | `perip/gpio/`      | APB  |
| UART 16550   | `perip/uart16550/` | APB  |
| SPI Master   | `perip/spi/`       | APB  |
| PS/2 控制器  | `perip/ps2/`       | APB  |
| VGA 控制器   | `perip/vga/`       | AXI4 |
| Flash        | `perip/flash/`     | SPI  |
| PSRAM        | `perip/psram/`     | SPI  |
| SDRAM        | `perip/sdram/`     | AXI4 |
| APB 总线延迟 | `perip/amba/`      | AMBA |

---

## 10. 地址空间映射

| 设备          | 地址范围                    | 大小    | 说明           |
| ------------- | --------------------------- | ------- | -------------- |
| CLINT         | `0x0200_0000 ~ 0x0200_ffff` | 64 KB   | 定时器中断     |
| SRAM          | `0x0f00_0000 ~ 0x0f00_1fff` | 8 KB    | 片内 SRAM      |
| TEST          | `0x0f00_2000 ~ 0x0fff_ffff` | ~256 MB | 测试辅助空间   |
| UART16550     | `0x1000_0000 ~ 0x1000_0fff` | 4 KB    | 串口           |
| SPI Master    | `0x1000_1000 ~ 0x1000_1fff` | 4 KB    | SPI 控制器     |
| GPIO          | `0x1000_2000 ~ 0x1000_200f` | 16 B    | 通用 IO        |
| PS/2          | `0x1001_1000 ~ 0x1001_1007` | 8 B     | 键盘控制器     |
| MROM          | `0x2000_0000 ~ 0x2000_0fff` | 4 KB    | Mask ROM       |
| VGA FB        | `0x2100_0000 ~ 0x211f_ffff` | 2 MB    | VGA 帧缓冲     |
| VGA CTRL      | `0x2200_0000 ~ 0x2200_0fff` | 4 KB    | VGA 控制寄存器 |
| Flash         | `0x3000_0000 ~ 0x3fff_ffff` | 256 MB  | NOR Flash      |
| ChipLink MMIO | `0x4000_0000 ~ 0x7fff_ffff` | 1 GB    | ChipLink MMIO  |
| PSRAM         | `0x8000_0000 ~ 0x9fff_ffff` | 512 MB  | 伪静态 RAM     |
| SDRAM         | `0xa000_0000 ~ 0xbfff_ffff` | 512 MB  | 同步动态 RAM   |
| ChipLink MEM  | `0xc000_0000 ~ 0xffff_ffff` | 1 GB    | ChipLink 内存  |

**GPIO 寄存器布局**（基地址 `0x1000_2000`）：

| 偏移   | 说明                                              |
| ------ | ------------------------------------------------- |
| `+0x0` | 16 位输出，驱动 16 个 LED                         |
| `+0x4` | 16 位输入，读取 16 个拨码开关                     |
| `+0x8` | 32 位输出，每 4 位驱动 1 个 7 段数码管（共 8 个） |
| `+0xC` | 保留                                              |

---

## 11. 指令集编码

### 11.1 指令码结构（16 位 inst_code）

```
[15:12] 类别标志  [11:0] 具体操作码
```

| 标志位         | 值       | 含义                 |
| -------------- | -------- | -------------------- |
| INST_CODE_JUMP | `0x1000` | 跳转/分支/系统调用类 |
| INST_CODE_MEM  | `0x2000` | 内存访问类           |
| INST_TYPE_R    | `0x0100` | R 型格式             |
| INST_TYPE_I    | `0x0200` | I 型格式             |
| INST_TYPE_S    | `0x0300` | S 型格式             |
| INST_TYPE_B    | `0x0400` | B 型格式             |
| INST_TYPE_U    | `0x0500` | U 型格式             |
| INST_TYPE_J    | `0x0600` | J 型格式             |

### 11.2 支持的指令集

**RV32I 基础整数指令集**：LUI, AUIPC, JAL, JALR, BEQ/BNE/BLT/BGE/BLTU/BGEU, LB/LH/LW/LBU/LHU, SB/SH/SW, ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI, ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND, FENCE/FENCE.I, ECALL/EBREAK, CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI

**RV32M 乘除扩展**：MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU

**特权指令**：MRET, SRET, WFI, SFENCE.VMA

### 11.3 异常类型（mcause 编码）

| 编号 | 名称 | 说明             |
| ---- | ---- | ---------------- |
| 0    | IAM  | 指令地址未对齐   |
| 1    | IAF  | 指令访问错误     |
| 2    | ILL  | 非法指令         |
| 3    | BRK  | 断点             |
| 4    | LAM  | Load 地址未对齐  |
| 5    | LAF  | Load 访问错误    |
| 6    | SAM  | Store 地址未对齐 |
| 7    | SAF  | Store 访问错误   |
| 8    | UEC  | U 模式 ECALL     |
| 9    | SEC  | S 模式 ECALL     |
| 11   | MEC  | M 模式 ECALL     |
| 12   | IPF  | 指令页错误       |
| 13   | LPF  | Load 页错误      |
| 15   | SPF  | Store 页错误     |

---

## 12. 软件仿真器架构

### 12.1 整体结构

```
npc-main.cpp
     │
     ├── monitor/          # 初始化、SDB 调试器
     ├── cpu/cpu-exec.cpp  # 执行循环（cpu_exec(n)）
     ├── isa/riscv32/      # ISA 实现
     │   ├── inst.cpp      # 指令执行
     │   ├── reg.cpp       # 寄存器操作
     │   └── system/       # CSR、MMU、中断
     ├── memory/           # 物理/虚拟地址管理
     └── device/           # 设备模型（UART、VGA、Timer 等）
```

### 12.2 CPU 状态

```c
typedef struct {
    word_t gpr[32];    // 通用寄存器
    vaddr_t pc;        // 程序计数器
    word_t csr[4096];  // CSR 寄存器（可选编译）
} riscv32_CPU_state;
```

### 12.3 执行引擎

- **引擎类型**：解释执行（Interpreter）
- **执行流**：`isa_exec_once()` → 获取指令 → 调用 `exec_vsimu()` → 更新 CPU 状态
- **解码结构体**：`Decode { inst, pc, snpc, dnpc, logbuf }`

### 12.4 设备模型

所有设备通过虚拟设备表（MMIO map）注册：

```c
struct vdev_item_t {
    const char *name;
    paddr_t startaddr, endaddr;
    uint8_t *raw_mem;
    void (*handler)(paddr_t, int, bool, ioaddr_t);
};
```

已实现的设备：UART16550、Timer/CLINT、VGA 帧缓冲、PS/2 键盘、GPIO、SPI Master、音频、磁盘、SD 卡

### 12.5 追踪系统

| 类型   | 宏              | 说明                   |
| ------ | --------------- | ---------------------- |
| ITRACE | `CONFIG_ITRACE` | 每条指令的 PC 和反汇编 |
| MTRACE | `CONFIG_MTRACE` | 内存读写追踪           |
| DTRACE | `CONFIG_DTRACE` | 设备 IO 追踪           |
| ETRACE | `CONFIG_ETRACE` | 异常/中断追踪          |

### 12.6 差分测试

- 与参考实现（NEMU、QEMU、Spike、KVM）逐指令对比 GPR/CSR 状态
- 检测仿真结果与参考的分歧
- 配置文件：`tools/difftest.mk`

---

## 13. 性能监控

**硬件计数器**（`vsrc/core/pipeline/perf_monitor.v`）：

| 计数器 ID                          | 含义              |
| ---------------------------------- | ----------------- |
| `HW_CPU_STAT_TICK` (0)             | 总时钟周期数      |
| `HW_CPU_STAT_ICACHE_HIT` (1)       | ICache 命中次数   |
| `HW_CPU_STAT_ICACHE_MISS` (2)      | ICache 未命中次数 |
| `HW_CPU_STAT_INST` (3)             | 执行指令数        |
| `HW_CPU_STAT_DATA` (4)             | 数据访问次数      |
| `HW_CPU_STAT_DCACHE_HIT` (5)       | DCache 命中次数   |
| `HW_CPU_STAT_DCACHE_MISS` (6)      | DCache 未命中次数 |

通过 DPI-C 接口 `dpi_cpu_stat_ctrl(dtype, delta)` 上报到仿真器软件端。

---

## 14. 构建系统

- **配置工具**：Kconfig（`Kconfig` + `configs/` 预设配置）
- **构建脚本**：`scripts/build.mk`, `scripts/native.mk`, `scripts/config.mk`
- **文件列表**：`src/filelist.mk`（C++ 源文件），`vsrc/filelist.mk`（Verilog 源文件）

主要编译目标配置（`riscv32-am_defconfig`）：

| 选项     | 值                         |
| -------- | -------------------------- |
| ISA      | riscv32                    |
| 执行引擎 | Interpreter                |
| 模式     | System（全特权模式）       |
| 调试功能 | ITRACE, MTRACE, SDB 调试器 |

---

## 15. 目录结构速查

```
npc/
├── include/          # C++ 头文件
│   ├── cpu/          # cpu.h, decode.h, difftest.h, ifetch.h
│   ├── device/       # mmio.h, vdev.h, dtrace.h
│   └── memory/       # paddr.h, vaddr.h, vmem.h
├── src/              # C++ 源文件
│   ├── cpu/          # cpu-exec.cpp（执行循环）
│   ├── isa/riscv32/  # inst.cpp, reg.cpp, system/
│   ├── device/       # 设备模型
│   ├── memory/       # paddr.cpp, vaddr.cpp, vmem.cpp
│   └── monitor/      # SDB 调试器
├── vsrc/             # Verilog 硬件源码
│   ├── core/
│   │   ├── pipeline/ # 五级流水线（主要实现）
│   │   ├── multiple/ # 多周期实现（参考）
│   │   ├── single/   # 单周期实现（参考）
│   │   └── common/   # 共享组件（gprs, csrs, cache, axi_master...）
│   ├── device/       # 总线组件（arbiter, xbar, clint, sram...）
│   ├── ysyxSoC/      # 完整 SoC 集成
│   └── nvboard/      # NVBoard 板级外设
├── test/             # 测试用例
├── resource/         # 测试二进制文件
├── tools/            # 辅助工具（cachesim, monitor_analyzer...）
├── scripts/          # 构建脚本
├── configs/          # Kconfig 预设配置
└── Read.md           # 外设地址空间说明
```