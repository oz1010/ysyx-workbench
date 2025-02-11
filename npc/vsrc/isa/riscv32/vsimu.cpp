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

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vtop.h"
#include "Vtop___024root.h"

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

std::shared_ptr<VerilatedContext> contextp;
std::shared_ptr<TOP_NAME> top;
std::shared_ptr<VerilatedVcdC> tfp;

typedef enum { SYNC_TO_SIMU, SYNC_TO_CPU } sync_type_t;

static int sync_simu_cpu(TOP_NAME *_simu, CPU_state *_cpu, sync_type_t type)
{
    if (type == SYNC_TO_SIMU){
        memcpy(&_simu->rootp->top__DOT__x.m_storage[0], &_cpu->gpr[0], sizeof(_cpu->gpr));
        _simu->rootp->top__DOT__pc = _cpu->pc;
    } else {
        memcpy(&_cpu->gpr[0], &_simu->rootp->top__DOT__x.m_storage[0], sizeof(_cpu->gpr));
        _cpu->pc = _simu->rootp->top__DOT__pc;
    }

    return 0;
}

int exec_vsimu(Decode *s)
{
    s->dnpc = s->snpc;

    // 同步cpu到模拟处理器
    sync_simu_cpu(top.get(), &cpu, SYNC_TO_SIMU);

    // 电路仿真
    // top->inst = s->isa.inst.val;
    top->clk = 1;
    top->contextp()->timeInc(1);
    top->eval();
    RECORD_TRACE_VCD();

    top->clk = 0;
    top->contextp()->timeInc(1);
    top->eval();
    RECORD_TRACE_VCD();

    // 同步模拟处理器到cpu
    sync_simu_cpu(top.get(), &cpu, SYNC_TO_CPU);

    s->dnpc = cpu.pc;

    return 0;
}

void init_vsimu(int argc, char *argv[])
{
    contextp = std::make_shared<VerilatedContext>();
    contextp->debug(0);                 // Set debug level, 0 is off, 9 is highest
    contextp->randReset(2);             // Randomization reset policy
    contextp->commandArgs(argc, argv);  // Pass arguments so Verilated code can see them

    top = std::make_shared<TOP_NAME>(contextp.get(), "top");

#if VM_TRACE_VCD
    Verilated::mkdir("build/logs");
    top->contextp()->traceEverOn(true);  // Verilator must compute traced signals
    tfp = std::make_shared<VerilatedVcdC>();
    top->trace(tfp.get(), 99);  // Trace 99 levels of hierarchy (or see below)
    tfp->open("build/logs/simu_top.vcd");
    LOG_INFO("Start trace ...\n");
#endif

    // 上电复位
    uint32_t clk = 0;
    top->rst = 1;
    for (int i = 0; i < 10; ++i)
    {
        clk = !clk;
        top->clk = clk;
        top->eval();
    }
    top->rst = 0;

    cpu.pc = top->rootp->top__DOT__pc;
}

void exit_vsimu()
{
    // Final model cleanup
    top->final();

    tfp.reset();
    top.reset();
	contextp.reset();
}
