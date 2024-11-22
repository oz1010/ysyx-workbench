#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <getopt.h>
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vtop.h"
#include "Vtop___024root.h"
#include "isa.h"
#include "dm/cpu_interface.h"
#include "debug.h"
#include "memory/paddr.h"

#if VM_TRACE_VCD
static void record_trace_vcd(VerilatedVcdC* tfp, VerilatedContext* contextp) {
	tfp->dump(contextp->time());
}
#define RECORD_TRACE_VCD() record_trace_vcd(tfp.get(), contextp.get())
#else
#define RECORD_TRACE_VCD()
#endif

std::unique_ptr<VerilatedContext> contextp;
std::unique_ptr<TOP_NAME> top;
std::unique_ptr<VerilatedVcdC> tfp;

cpu_opt_t rv_cpu_opt;
CPU_state cpu;

static void statistic()
{
  	IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
	#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") "lu"
	Log("host time spent = " NUMBERIC_FMT " us", npc_ctx.timer);
	Log("total guest instructions = " NUMBERIC_FMT, npc_ctx.nr_guest_inst);
	if (npc_ctx.timer > 0) Log("simulation frequency = " NUMBERIC_FMT " inst/s", npc_ctx.nr_guest_inst * 1000000 / npc_ctx.timer);
	else Log("Finish running in less than 1 us and can not calculate the simulation frequency");
}

static word_t * rv_get_gpr(CPU_state *c, size_t idx)
{
	assert(idx<ARRAY_SIZE(c->gpr) && "get gpr is out of range");
	return &c->gpr[idx];
}
static int rv_access_mem(uint32_t write, uint32_t pc, uint32_t size, uint8_t *data)
{
	const uint32_t idx = pc - CONFIG_MBASE;

	if (idx <= CONFIG_MSIZE) {
		// 内存区域
		if (write) {
			write_memory(pc, size, data);
		} else {
			read_memory(pc, size, data);
		}
	} else {
		LOG_ERROR("%s memory is out of range, pc:%#x idx:%#x size:%u check:%d CONFIG_MSIZE:%u", write?"write":"read", pc, idx, size, (idx <= CONFIG_MSIZE), CONFIG_MSIZE);
		assert(0);
	}

	return 0;
}

static void exec_once(/*Decode *s, vaddr_t pc*/) {
}

static void execute(uint64_t n) {
    for (;n > 0; n --) {

    }
}

void assert_fail_msg() {
//   isa_reg_display();
    statistic();
	LOG_ERROR("assert failed, current pc:%#.8x", cpu.pc);
}

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n)
{
    const uint64_t sim_time = CONFIG_MSIZE;
    while(top->contextp()->time()<sim_time && !top->contextp()->gotFinish() && npc_ctx.state==NPC_STOP) {
        for(int i=0; i<32; ++i)
            cpu.gpr[i] = top->rootp->top__DOT__regs_output[i];
        cpu.pc = top->rootp->addr;

		// 模拟从内存读数据
		top->clk = !top->clk;
		if (top->clk) {
			switch(npc_ctx.state) 
			{
				case NPC_END: case NPC_ABORT:
					LOG_ERROR("Program execution has ended. To restart the program, exit NPC and run again.");
					return;
				
				default: npc_ctx.state = NPC_RUNNING;
			}

			uint32_t data = inst_fetch(cpu.pc);
			if (!data)
			{
				panic("simulator read NULL mem data\n");
				break;
			}
            top->data = data;
			
#if CONFIG_DEBUG_MODULE
		  	// read instruction before debug
			data = inst_fetch(cpu.pc);
			dtm_update(DM_EXEC_INST_BEFORE, data, &cpu);

			// read instruction before execution
			data = inst_fetch(cpu.pc);
#else
  			data = inst_fetch(cpu.pc);
#endif
			npc_ctx.nr_guest_inst++;
		}

		uint64_t timer_start = get_time();
		// 电路仿真
		top->contextp()->timeInc(1);
		top->eval();
		RECORD_TRACE_VCD();
		uint64_t timer_end = get_time();
		npc_ctx.timer += timer_end - timer_start;

		if (top->clk) {
			IFDEF(CONFIG_DEBUG_MODULE, dtm_update(DM_EXEC_INST_AFTER, data, &cpu));
			switch (npc_ctx.state) {
				case NPC_RUNNING: npc_ctx.state = NPC_STOP; break;

				case NPC_END:
				case NPC_ABORT:
				Log("nemu: %s at pc = " FMT_WORD,
					(npc_ctx.state == NPC_ABORT ? ANSI_FMT("ABORT", ANSI_FG_RED) :
					(npc_ctx.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) :
						ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
					npc_ctx.halt_pc);
					// fall through
				case NPC_QUIT: statistic();
			}
		}
	}
}

void init_cpu(int argc, char *argv[]) {
#if CONFIG_DEBUG_MODULE
	// 初始化调试模块
	rv_cpu_opt.get_gpr = rv_get_gpr;
	rv_cpu_opt.access_mem = rv_access_mem;
	dtm_init(&rv_cpu_opt);
#endif

    contextp = std::make_unique<VerilatedContext>();
	contextp->debug(0); // Set debug level, 0 is off, 9 is highest
	contextp->randReset(2); // Randomization reset policy
	contextp->commandArgs(argc, argv); // Pass arguments so Verilated code can see them

	top = std::make_unique<TOP_NAME>(contextp.get(), "top");

#if VM_TRACE_VCD
	Verilated::mkdir("build/logs");
	top->contextp()->traceEverOn(true); // Verilator must compute traced signals
	tfp = std::make_unique<VerilatedVcdC>();
	top->trace(tfp.get(), 99); // Trace 99 levels of hierarchy (or see below)
	tfp->open("build/logs/simu_top.vcd");
	LOG_INFO("Start trace ...\n");
#endif

    // 上电复位
	uint32_t clk = 1;
	top->rst = 1;
	for (int i=0; i<10; ++i) {
		clk = !clk;
		top->clk = clk;
		top->eval();
	}
	top->rst = 0;
}
