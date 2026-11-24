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
#include <algorithm>
#include <deque>
#include <iterator>
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
#include "device/ps2.h"

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

#define TOP_RUN_HALF_TICK(T)       \
    do                             \
    {                              \
        T->clock = !T->clock;      \
        T->contextp()->timeInc(1); \
        T->eval();                 \
        RECORD_TRACE();            \
    } while (0)

#define TOP_RUN_TICK(T)       \
    do                        \
    {                         \
        TOP_RUN_HALF_TICK(T); \
        TOP_RUN_HALF_TICK(T); \
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
    SYNC_COLLECT,  // 采集核心写口
    SYNC_COMMIT    // 执行指令完成时
} sync_type_t;

static int sync_simu_cpu(TOP_ROOT_CLASS* _simu, CPU_state* _cpu, sync_type_t type)
{
    typedef struct
    {
        paddr_t inst_pc;
        uint32_t waddr;
        uint32_t wdata;
    } gpr_write_t;
    typedef struct
    {
        paddr_t inst_pc;
        bool wen;
        uint32_t waddr;
        uint32_t wdata;
        bool trap_en;
        uint32_t epc;
        uint32_t cause;
        uint32_t tval;
        uint32_t status;
    } csr_write_t;
    static std::deque<gpr_write_t> gpr_write_queue = {};
    static std::deque<csr_write_t> csr_write_queue = {};

    static VlUnpacked<IData /*31:0*/, 1>* write_inst_pc = &_simu->rootp->MUXDEF(
        CONFIG_ISA_RISCV_SINGLE, TOP_SIGNAL(core_pc), TOP_SIGNAL(core_inst_pc));
    static CData* gpr_wen = &_simu->rootp->TOP_SIGNAL(gpr_wen);
    static CData* gpr_waddr = &_simu->rootp->TOP_SIGNAL(gpr_waddr);
    static IData* gpr_wdata = &_simu->rootp->TOP_SIGNAL(gpr_wdata);
    static CData* csr_wen = &_simu->rootp->TOP_SIGNAL(csr_wen);
    static SData* csr_waddr = &_simu->rootp->TOP_SIGNAL(csr_waddr);
    static IData* csr_wdata = &_simu->rootp->TOP_SIGNAL(csr_wdata);
    static CData* trap_en = &_simu->rootp->TOP_SIGNAL(trap_en);
    static IData* trap_epc = &_simu->rootp->TOP_SIGNAL(trap_epc);
    static IData* trap_cause = &_simu->rootp->TOP_SIGNAL(trap_cause);
    static IData* trap_tval = &_simu->rootp->TOP_SIGNAL(trap_tval);
    static IData* trap_status = &_simu->rootp->TOP_SIGNAL(trap_status);
    static VlUnpacked<IData /*31:0*/, 1>* inst_pc = &_simu->rootp->TOP_SIGNAL(core_inst_pc);

    // SoC内部复位链释放前的组合写口无效，不能进入提交队列
    if (_simu->rootp->TOP_SIGNAL(reset))
    {
        gpr_write_queue.clear();
        csr_write_queue.clear();
        return 0;
    }

    switch (type)
    {
        case SYNC_COLLECT:
        {
            // 采集gpr
            if (*gpr_wen && *gpr_waddr != 0)
            {
                gpr_write_queue.push_back({(*write_inst_pc)[0], *gpr_waddr, *gpr_wdata});
            }

            // 普通csr写和trap按指令采集，提交时再同步软件状态
            if (*csr_wen || *trap_en)
            {
                csr_write_queue.push_back({(*write_inst_pc)[0], bool(*csr_wen), *csr_waddr,
                                           *csr_wdata, bool(*trap_en), *trap_epc, *trap_cause,
                                           *trap_tval, *trap_status});
            }
            break;
        }
        case SYNC_COMMIT:
        {
            // 写入gpr提交
            auto item = std::find_if(gpr_write_queue.begin(), gpr_write_queue.end(),
                                     [](const gpr_write_t& write)
                                     { return write.inst_pc == (*inst_pc)[0]; });
            if (item != gpr_write_queue.end())
            {
                _cpu->gpr[item->waddr] = item->wdata;
                gpr_write_queue.erase(gpr_write_queue.begin(), std::next(item));
            }
            // 与csrs一致：只镜像可写寄存器，trap覆盖同拍普通写
            auto csr_item = std::find_if(csr_write_queue.begin(), csr_write_queue.end(),
                                         [](const csr_write_t& write)
                                         { return write.inst_pc == (*inst_pc)[0]; });
            if (csr_item != csr_write_queue.end())
            {
                if (csr_item->wen)
                {
                    switch (csr_item->waddr)
                    {
                        case CSR_MSTATUS:
                        case CSR_MTVEC:
                        case CSR_MEPC:
                        case CSR_MCAUSE:
                        case CSR_MTVAL:
                            _cpu->csr[csr_item->waddr] = csr_item->wdata;
                            break;
                        default:
                            break;
                    }
                }
                if (csr_item->trap_en)
                {
                    _cpu->csr[CSR_MSTATUS] = csr_item->status;
                    _cpu->csr[CSR_MEPC] = csr_item->epc;
                    _cpu->csr[CSR_MCAUSE] = csr_item->cause;
                    _cpu->csr[CSR_MTVAL] = csr_item->tval;
                    switch (csr_item->cause)
                    {
                        case EXPT_CAUSE_ILL:
                            invalid_inst(csr_item->epc, csr_item->tval);
                            break;
                        case EXPT_CAUSE_BRK:
                            set_npc_state(NPC_END, csr_item->inst_pc, csr_item->tval);
                            break;
                        default:
                            break;
                    }
                }
                csr_write_queue.erase(csr_write_queue.begin(), std::next(csr_item));
            }
            _cpu->pc = _simu->rootp->TOP_SIGNAL(core_pc)[0];
            break;
        }
        default:
            break;
    }

    return 0;
}

int exec_vsimu(Decode* s)
{
    bool simu_continue;

    do
    {
        // 电路仿真
        IFDEF(CONFIG_HAS_NVBOARD, nvboard_update());
#if defined(CONFIG_HAS_PS2) && !defined(CONFIG_HAS_NVBOARD)
        terminal_ps2_update();
#endif
#if CONFIG_ISA_RISCV_SINGLE
        // 单周期写口在上升沿后已属于下一条指令，必须在上升沿前采集
        TOP_RUN_HALF_TICK(top);
        sync_simu_cpu(top.get(), &cpu, SYNC_COLLECT);
        TOP_RUN_HALF_TICK(top);
#else
        TOP_RUN_TICK(top);
        sync_simu_cpu(top.get(), &cpu, SYNC_COLLECT);
#endif

        simu_continue =
            !top->contextp()->gotFinish() &&
            (npc_ctx.state == NPC_RUNNING || npc_ctx.state == NPC_END || npc_ctx.state == NPC_QUIT);
        for (int idx = 0; idx < CONFIG_CORE_NUM; ++idx)
        {
            if (top->rootp->TOP_SIGNAL(core_inst_done)[idx])
            {
                sync_simu_cpu(top.get(), &cpu, SYNC_COMMIT);
                simu_continue = false;
                break;
            }
            if (top->rootp->TOP_SIGNAL(core_error)[idx])
            {
                printf(ANSI_FMT("Found error in core%d", ANSI_BG_RED) "\n", idx);
                set_npc_state(NPC_ABORT, get_vsimu_pc(), -4);
                simu_continue = false;
                break;
            }
        }
    } while (simu_continue);

    // s->dynamic_next_pc = get_vsimu_dnpc();

    // 仿真直接调用finish，强制修改状态
    if (top->contextp()->gotFinish() && npc_ctx.state == NPC_RUNNING)
    {
        printf(ANSI_FMT("Found finish in verilog\n", ANSI_BG_RED));
        set_npc_state(NPC_ABORT, get_vsimu_pc(), -5);
    }

#if !CONFIG_ISA_RISCV_SINGLE
    // 非单周期，需要额外的半周期来完成数据的采集
    if (npc_ctx.state == NPC_END)
    {
        TOP_RUN_TICK(top);
    }
#endif

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
#if defined(CONFIG_HAS_PS2) && !defined(CONFIG_HAS_NVBOARD)
    terminal_ps2_init(&top->externalPins_ps2_clk, &top->externalPins_ps2_data);
#endif

#if VM_TRACE
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
#endif

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
#if defined(CONFIG_HAS_PS2) && !defined(CONFIG_HAS_NVBOARD)
    terminal_ps2_shutdown();
#endif

    // Final model cleanup
    top->final();

#if VM_TRACE
    if (cfg_hw_trace)
    {
        tfp.reset();
    }
#endif
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

paddr_t get_vsimu_pc(void)
{
    return top->rootp->TOP_SIGNAL(core_pc)[0];
}
