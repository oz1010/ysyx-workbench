#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include "Vtop.h"
#include "verilated.h"

#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
static void record_trace_vcd(VerilatedVcdC* tfp, VerilatedContext* contextp) {
	tfp->dump(contextp->time());
}
#define RECORD_TRACE_VCD() record_trace_vcd(tfp.get(), contextp.get())
#else
#define RECORD_TRACE_VCD()
#endif

typedef TOP_NAME* top_ptr;

int main(int argc, char** argv) {
	const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
	contextp->debug(0); // Set debug level, 0 is off, 9 is highest
	contextp->randReset(2); // Randomization reset policy
	contextp->commandArgs(argc, argv); // Pass arguments so Verilated code can see them

	const std::unique_ptr<TOP_NAME> top{new TOP_NAME{contextp.get(), "top"}};

#if VM_TRACE_VCD
	Verilated::mkdir("build/logs");
	contextp->traceEverOn(true); // Verilator must compute traced signals
	const std::unique_ptr<VerilatedVcdC>tfp{new VerilatedVcdC};
	top->trace(tfp.get(), 99); // Trace 99 levels of hierarchy (or see below)
	tfp->open("build/logs/simu_top.vcd");
	printf("Start trace ...\n");
#endif

	uint64_t sim_time = 10;

	while(contextp->time()<sim_time && !contextp->gotFinish()) {
		// 生成测试数据
		top->a = rand() % 16;
		top->s = rand() % 4;

		// 电路仿真一次
		contextp->timeInc(1);
		top->eval();
		RECORD_TRACE_VCD();
	}

	return 0;
}