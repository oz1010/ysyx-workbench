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
#include "test_top_define.h"

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
std::shared_ptr<TOP_ROOT_CLASS> top;
std::shared_ptr<VerilatedVcdC> tfp;

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
}

void exit_vsimu()
{
    // Final model cleanup
    top->final();

    tfp.reset();
    top.reset();
    contextp.reset();
}


int main(int argc, char *argv[]) {
    printf("Verilog test case is running.\n");
    init_vsimu(argc, argv);

    int cnt = 0;
    uint32_t clock = 0;
    top->reset = 0;
    while(!top->contextp()->gotFinish() && cnt++<18) {
        top->clock = clock;
        clock = !clock;
        top->contextp()->timeInc(1);
        top->eval();
        RECORD_TRACE_VCD();
    }
    
    exit_vsimu();

    printf("Verilog test case is exiting.\n");
    return 0;
}
