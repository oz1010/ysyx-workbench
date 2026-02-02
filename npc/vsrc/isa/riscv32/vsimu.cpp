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

#include "verilated.h"
#include "verilated_vcd_c.h"
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

#if VM_TRACE_VCD
static void record_trace_vcd(VerilatedVcdC *tfp, VerilatedContext *contextp)
{
    tfp->dump(contextp->time());
}
#define RECORD_TRACE_VCD() record_trace_vcd(tfp.get(), contextp.get())
#else
#define RECORD_TRACE_VCD()
#endif

extern void set_npc_state(npc_state_t state, vaddr_t pc, int halt_ret);
paddr_t get_vsimu_pc(void);

void init_dpi();
void exit_dpi();
uint8_t *get_vsimu_sram_addr();
std::shared_ptr<VerilatedContext> contextp;
std::shared_ptr<TOP_ROOT_CLASS> top;
std::shared_ptr<VerilatedVcdC> tfp;

typedef enum { SYNC_TO_SIMU, SYNC_TO_CPU } sync_type_t;

static int sync_simu_cpu(TOP_ROOT_CLASS *_simu, CPU_state *_cpu, sync_type_t type)
{
    // TOP_S_X
    // _simu->rootp->ysyxSoCFull__DOT__asic__DOT__cpu__DOT__cpu__DOT__ysyx_23060295_CORE0__DOT__m_reg_group__DOT__x
    if (type == SYNC_TO_SIMU){
        memcpy(&_simu->rootp->TOP_S_X.m_storage[0], &_cpu->gpr[0], sizeof(_cpu->gpr));
        _simu->rootp->TOP_S_PC = _cpu->pc;
    } else {
        memcpy(&_cpu->gpr[0], &_simu->rootp->TOP_S_X.m_storage[0], sizeof(_cpu->gpr));
        _cpu->pc = _simu->rootp->TOP_S_PC;
    }

    return 0;
}

int exec_vsimu(Decode *s)
{
    bool simu_continue;
    s->dnpc = s->snpc;

    // 同步cpu到模拟处理器
    sync_simu_cpu(top.get(), &cpu, SYNC_TO_SIMU);

    do
    {
        IFDEF(CONFIG_HAS_NVBOARD, nvboard_update());

        // 电路仿真
        // top->inst = s->isa.inst.val;
        top->clock = !top->clock;
        top->contextp()->timeInc(1);
        top->eval();
        RECORD_TRACE_VCD();

        top->clock = !top->clock;
        top->contextp()->timeInc(1);
        top->eval();
        RECORD_TRACE_VCD();

        // if (top->contextp()->time() >= 1000000) {
        //     LOG_ERROR("end simulator in debug time:%lu", top->contextp()->time());
        //     exit(-1);
        // }

        simu_continue = !top->contextp()->gotFinish() && (npc_ctx.state==NPC_RUNNING || npc_ctx.state==NPC_END || npc_ctx.state==NPC_QUIT);
        for (int idx=0; idx<CONFIG_CORE_NUM; ++idx) {
            if (top->rootp->TOP_S_CORE_INST_DONE[idx]) {
                simu_continue = false;
                break;
            }
            if (top->rootp->TOP_S_CORE_ERROR[idx]) {
                printf(ANSI_FMT("Found error in core%d\n", ANSI_BG_RED), idx);
                set_npc_state(NPC_ABORT, get_vsimu_pc(), -4);
                simu_continue = false;
                break;
            }
        }
    } while (simu_continue);


    // 同步模拟处理器到cpu
    sync_simu_cpu(top.get(), &cpu, SYNC_TO_CPU);

    s->dnpc = cpu.pc;

    // 仿真直接调用finish，强制修改状态
    if (top->contextp()->gotFinish() && npc_ctx.state == NPC_RUNNING) {
        printf(ANSI_FMT("Found finish in verilog\n", ANSI_BG_RED));
        set_npc_state(NPC_ABORT, get_vsimu_pc(), -5);
    }

#if CONFIG_PERF_MONITOR
    if (top->rootp->TOP_S_CORE_INST_DONE[0]) {
        extern void add_monitor_item(int item_idx, int id, int delta);
        add_monitor_item(1, 5, 1);
    }
#endif

    return 0;
}

void init_vsimu(int argc, char *argv[])
{
    Verilated::commandArgs(argc, argv);
    contextp = std::make_shared<VerilatedContext>();
    contextp->debug(0);                 // Set debug level, 0 is off, 9 is highest
    contextp->randReset(2);             // Randomization reset policy
    // contextp->commandArgs(argc, argv);  // Pass arguments so Verilated code can see them

    top = std::make_shared<TOP_ROOT_CLASS>(contextp.get(), TOP_STR);

#if VM_TRACE_VCD
    Verilated::mkdir("build/logs");
    top->contextp()->traceEverOn(true);  // Verilator must compute traced signals
    tfp = std::make_shared<VerilatedVcdC>();
    top->trace(tfp.get(), 99);  // Trace 99 levels of hierarchy (or see below)
    tfp->open("build/logs/simu_top.vcd");
    LOG_INFO("Start trace ...\n");
#endif

    // 初始化NVBoard
    IFDEF(CONFIG_HAS_NVBOARD, nvboard_bind_all_pins(top.get()));
    IFDEF(CONFIG_HAS_NVBOARD, nvboard_init());

    // 初始化dpi
    init_dpi();

    // 上电复位
    top->clock = 1;
    top->reset = 1;
    for (int i = 0; i < 28; ++i)
    {
        top->clock = !top->clock;
        top->contextp()->timeInc(1);
        top->eval();
        RECORD_TRACE_VCD();
    }
    top->reset = 0;

    cpu.pc = get_vsimu_pc();
}

void exit_vsimu()
{
    IFDEF(CONFIG_HAS_NVBOARD, nvboard_quit());

    // Final model cleanup
    top->final();

    tfp.reset();
    top.reset();
	contextp.reset();

    exit_dpi();
}

uint8_t *get_vsimu_sram_addr()
{
    return (uint8_t *)&top->rootp->TOP_ASIC_AXI4RAM_MEMORY[0];
}

uint32_t *get_vsimu_vga_fb_addr()
{
    return (uint32_t *)&top->rootp->ysyxSoCFull__DOT__asic__DOT__lvga__DOT__mvga__DOT__m_vga_regs__DOT__fram_buffer[0];
}

uint32_t *get_vsimu_vga_ctrl_regs_addr()
{
    return (uint32_t *)&top->rootp->ysyxSoCFull__DOT__asic__DOT__lvga__DOT__mvga__DOT__m_vga_regs__DOT__ctrl_regs[0];
}

void set_vsimu_pc(paddr_t addr)
{
    top->rootp->TOP_S_PC = addr;
}

paddr_t get_vsimu_pc(void)
{
    return top->rootp->TOP_S_PC;
}
