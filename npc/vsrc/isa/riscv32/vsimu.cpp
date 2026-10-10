/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>

#include <cpu/decode.h>

#include "generated/autoconf.h"
#include "dm/dtm.h"
#include "macro.h"
#include "trace.h"

#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#elif VM_TRACE_VCD
#include "verilated_vcd_c.h"
#endif
#include "top_define.h"

#if CONFIG_HAS_NVBOARD
#include "nvboard.h"
void nvboard_bind_all_pins(TOP_ROOT_CLASS* _simu);
#endif

/* The assembly code of instructions executed is only output to the screen
 * when the number of instructions executed is less than this value.
 * This is useful when you use the `si' command.
 * You can modify this value as you want.
 */
#define MAX_INST_TO_PRINT 10

extern std::string cfg_output;
extern bool cfg_hw_trace;

#if VM_TRACE_FST
#define VERILATED_TRACE_C VerilatedFstC
#define VERILATED_TRACE_FILE_EXT ".fst"
#elif VM_TRACE_VCD
#define VERILATED_TRACE_C VerilatedVcdC
#define VERILATED_TRACE_FILE_EXT ".vcd"
#else
#define VERILATED_TRACE_C void
#define VERILATED_TRACE_FILE_EXT ".bin"
#endif

#if VM_TRACE
static void record_trace(VERILATED_TRACE_C* tfp, VerilatedContext* contextp)
{
    tfp->dump(contextp->time());
}
#define RECORD_TRACE()                               \
    do                                               \
    {                                                \
        if (cfg_hw_trace)                            \
        {                                            \
            record_trace(tfp.get(), contextp.get()); \
        }                                            \
    } while (0)
#else
#define RECORD_TRACE()
#endif

#define TOP_RUN_TICK(T)            \
    do                             \
    {                              \
        T->clock = !T->clock;      \
        T->contextp()->timeInc(1); \
        T->eval();                 \
        RECORD_TRACE();            \
        T->clock = !T->clock;      \
        T->contextp()->timeInc(1); \
        T->eval();                 \
        RECORD_TRACE();            \
    } while (0)

extern void set_npc_state(npc_state_t state, vaddr_t pc, int halt_ret);
extern paddr_t get_vsimu_pc(void);
extern paddr_t get_vsimu_dnpc(void);

void init_dpi();
void exit_dpi();
uint8_t* get_vsimu_sram_addr();
std::shared_ptr<VerilatedContext> contextp;
std::shared_ptr<TOP_ROOT_CLASS> top;
std::shared_ptr<VERILATED_TRACE_C> tfp;
VERILATED_TRACE_C* g_trace_tfp = nullptr;
VerilatedContext* g_trace_contextp = nullptr;

typedef enum
{
    SYNC_TO_SIMU,
    SYNC_TO_CPU
} sync_type_t;

static int sync_simu_cpu(TOP_ROOT_CLASS* _simu, CPU_state* _cpu, sync_type_t type)
{
    // RV32E GPR只有16个
    static size_t gpr_bytes = 16 * sizeof(_cpu->gpr[0]);
    // TOP_S_X
    // _simu->rootp->ysyxSoCFull__DOT__asic__DOT__cpu__DOT__cpu__DOT__ysyx_23060295_CORE0__DOT__m_reg_group__DOT__x
    if (type == SYNC_TO_SIMU)
    {
#ifdef CONFIG_ISA_RISCV_PIPELINE_CHISEL
        _simu->rootp->concat(TOP_S_X, _0) = _cpu->gpr[0];
        _simu->rootp->concat(TOP_S_X, _1) = _cpu->gpr[1];
        _simu->rootp->concat(TOP_S_X, _2) = _cpu->gpr[2];
        _simu->rootp->concat(TOP_S_X, _3) = _cpu->gpr[3];
        _simu->rootp->concat(TOP_S_X, _4) = _cpu->gpr[4];
        _simu->rootp->concat(TOP_S_X, _5) = _cpu->gpr[5];
        _simu->rootp->concat(TOP_S_X, _6) = _cpu->gpr[6];
        _simu->rootp->concat(TOP_S_X, _7) = _cpu->gpr[7];
        _simu->rootp->concat(TOP_S_X, _8) = _cpu->gpr[8];
        _simu->rootp->concat(TOP_S_X, _9) = _cpu->gpr[9];
        _simu->rootp->concat(TOP_S_X, _10) = _cpu->gpr[10];
        _simu->rootp->concat(TOP_S_X, _11) = _cpu->gpr[11];
        _simu->rootp->concat(TOP_S_X, _12) = _cpu->gpr[12];
        _simu->rootp->concat(TOP_S_X, _13) = _cpu->gpr[13];
        _simu->rootp->concat(TOP_S_X, _14) = _cpu->gpr[14];
        _simu->rootp->concat(TOP_S_X, _15) = _cpu->gpr[15];
#else
        memcpy(&_simu->rootp->TOP_S_X.m_storage[0], &_cpu->gpr[0], gpr_bytes);
#endif
        _simu->rootp->TOP_S_PC = _cpu->pc;
    }
    else
    {
#ifdef CONFIG_ISA_RISCV_PIPELINE_CHISEL
        _cpu->gpr[0] = _simu->rootp->concat(TOP_S_X, _0);
        _cpu->gpr[1] = _simu->rootp->concat(TOP_S_X, _1);
        _cpu->gpr[2] = _simu->rootp->concat(TOP_S_X, _2);
        _cpu->gpr[3] = _simu->rootp->concat(TOP_S_X, _3);
        _cpu->gpr[4] = _simu->rootp->concat(TOP_S_X, _4);
        _cpu->gpr[5] = _simu->rootp->concat(TOP_S_X, _5);
        _cpu->gpr[6] = _simu->rootp->concat(TOP_S_X, _6);
        _cpu->gpr[7] = _simu->rootp->concat(TOP_S_X, _7);
        _cpu->gpr[8] = _simu->rootp->concat(TOP_S_X, _8);
        _cpu->gpr[9] = _simu->rootp->concat(TOP_S_X, _9);
        _cpu->gpr[10] = _simu->rootp->concat(TOP_S_X, _10);
        _cpu->gpr[11] = _simu->rootp->concat(TOP_S_X, _11);
        _cpu->gpr[12] = _simu->rootp->concat(TOP_S_X, _12);
        _cpu->gpr[13] = _simu->rootp->concat(TOP_S_X, _13);
        _cpu->gpr[14] = _simu->rootp->concat(TOP_S_X, _14);
        _cpu->gpr[15] = _simu->rootp->concat(TOP_S_X, _15);
#else
        memcpy(&_cpu->gpr[0], &_simu->rootp->TOP_S_X.m_storage[0], gpr_bytes);
#endif
        _cpu->pc = _simu->rootp->TOP_S_PC;
    }

    return 0;
}

int exec_vsimu(Decode* s)
{
    bool simu_continue;
    s->dnpc = s->snpc;

    // 同步cpu到模拟处理器
    sync_simu_cpu(top.get(), &cpu, SYNC_TO_SIMU);

    do
    {
        // 电路仿真
        IFDEF(CONFIG_HAS_NVBOARD, nvboard_update());
        TOP_RUN_TICK(top);

        // if (top->contextp()->time() >= 1000000) {
        //     LOG_ERROR("end simulator in debug time:%lu", top->contextp()->time());
        //     exit(-1);
        // }

        simu_continue =
            !top->contextp()->gotFinish() &&
            (npc_ctx.state == NPC_RUNNING || npc_ctx.state == NPC_END || npc_ctx.state == NPC_QUIT);
        for (int idx = 0; idx < CONFIG_CORE_NUM; ++idx)
        {
            if (top->rootp->TOP_S_CORE_INST_DONE[idx])
            {
                // 此时done命令刚触发，需要再运行一个周期采集完整的数据
                IFDEF(CONFIG_HAS_NVBOARD, nvboard_update());
                TOP_RUN_TICK(top);
                simu_continue = false;
                break;
            }
            if (top->rootp->TOP_S_CORE_ERROR[idx])
            {
                printf(ANSI_FMT("Found error in core%d", ANSI_BG_RED) "\n", idx);
                set_npc_state(NPC_ABORT, get_vsimu_pc(), -4);
                simu_continue = false;
                break;
            }
        }
    } while (simu_continue);

    // 同步模拟处理器到cpu
    sync_simu_cpu(top.get(), &cpu, SYNC_TO_CPU);

    s->dnpc = get_vsimu_dnpc();

    // 仿真直接调用finish，强制修改状态
    if (top->contextp()->gotFinish() && npc_ctx.state == NPC_RUNNING)
    {
        printf(ANSI_FMT("Found finish in verilog\n", ANSI_BG_RED));
        set_npc_state(NPC_ABORT, get_vsimu_pc(), -5);
    }

    return 0;
}

void init_vsimu(int argc, char* argv[])
{
    Verilated::commandArgs(argc, argv);
    contextp = std::make_shared<VerilatedContext>();
    contextp->debug(0);      // Set debug level, 0 is off, 9 is highest
    contextp->randReset(2);  // Randomization reset policy
    // contextp->commandArgs(argc, argv);  // Pass arguments so Verilated code can see them

    top = std::make_shared<TOP_ROOT_CLASS>(contextp.get(), TOP_STR);

    std::string trace_path = cfg_output + "/trace";
    std::string trace_file;
    if (cfg_hw_trace)
    {
        Verilated::mkdir(trace_path.c_str());
        top->contextp()->traceEverOn(true);  // Verilator must compute traced signals
        tfp = std::make_shared<VERILATED_TRACE_C>();
        trace_file = trace_path + "/";
        trace_file += "simu_top";
        trace_file += VERILATED_TRACE_FILE_EXT;
        g_trace_tfp = tfp.get();
        g_trace_contextp = contextp.get();
        top->trace(tfp.get(), 99);  // Trace 99 levels of hierarchy (or see below)
        tfp->open(trace_file.c_str());
        LOG_INFO("Trace is written to %s\n", trace_file.c_str());
    }

    // 初始化NVBoard
    IFDEF(CONFIG_HAS_NVBOARD, nvboard_bind_all_pins(top.get()));
    IFDEF(CONFIG_HAS_NVBOARD, nvboard_init());

    // 初始化dpi
    init_dpi();

    // 上电复位
    top->clock = 1;
    top->reset = 1;
    for (int i = 0; i < 14; ++i)
    {
        TOP_RUN_TICK(top);
    }
    top->reset = 0;

    cpu.pc = get_vsimu_pc();
}

void exit_vsimu()
{
    IFDEF(CONFIG_HAS_NVBOARD, nvboard_quit());

    // Final model cleanup
    top->final();

    if (cfg_hw_trace)
    {
        tfp.reset();
    }
    top.reset();
    contextp.reset();

    exit_dpi();
}

uint8_t* get_vsimu_sram_addr()
{
    return (uint8_t*)&top->rootp->TOP_ASIC_AXI4RAM_MEMORY[0];
}

uint32_t* get_vsimu_vga_fb_addr()
{
    return (uint32_t*)&top->rootp
        ->ysyxSoCFull__DOT__asic__DOT__lvga__DOT__mvga__DOT__m_vga_regs__DOT__fram_buffer[0];
}

uint32_t* get_vsimu_vga_ctrl_regs_addr()
{
    return (uint32_t*)&top->rootp
        ->ysyxSoCFull__DOT__asic__DOT__lvga__DOT__mvga__DOT__m_vga_regs__DOT__ctrl_regs[0];
}

void set_vsimu_pc(paddr_t addr)
{
    top->rootp->TOP_S_PC = addr;
}

paddr_t get_vsimu_pc(void)
{
    return top->rootp->TOP_S_PC;
}

paddr_t get_vsimu_dnpc(void)
{
    return top->rootp->TOP_S_DNPC;
}

uint32_t get_csr_index(paddr_t addr)
{
    static const auto csr_addrs = []
    {
        std::array<uint32_t, CSR_COUNT + 1> a{};
        a[CSR_MSTATUS] = 1;
        a[CSR_MTVEC] = 2;
        a[CSR_MEPC] = 3;
        a[CSR_MCAUSE] = 4;
        a[CSR_MVENDORID] = 5;
        a[CSR_MARCHID] = 6;
        return a;
    }();
    // 需要保持和vsrc/core/common/csrs.v get_csr_index一致的逻辑，否则容易出问题
    // static const size_t csr_index_max = top->rootp->TOP_S_CSR.size();
    // static_assert(csr_index_max == ARRAY_SIZE(csr_addrs), "csr count may be dismatched");

    uint32_t csr_index = csr_addrs[addr & 0xfff];
    return csr_index;
}
void set_vsimu_csr(paddr_t addr, uint32_t data)
{
#if CONFIG_ISA_RISCV_SINGLE
    cpu.csr[addr] = data;
#else
#if CONFIG_DIFFTEST
    // 开diff后，需要将数据同步写入cpu.csr，用于同步到ref中。
    cpu.csr[addr] = data;
#endif
    top->rootp->TOP_S_CSR[get_csr_index(addr)] = data;
#endif
}
uint32_t get_vsimu_csr(paddr_t addr)
{
#if CONFIG_ISA_RISCV_SINGLE
    uint32_t data = cpu.csr[addr];
#else
    uint32_t data = top->rootp->TOP_S_CSR[get_csr_index(addr)];
#endif
    return data;
}
