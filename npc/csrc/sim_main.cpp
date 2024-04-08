#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <nvboard.h>
#include "Vtop.h"
#include "verilated.h"

#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
#endif

typedef TOP_NAME* top_ptr;

void nvboard_bind_all_pins(TOP_NAME* top);

static void single_cycle(top_ptr top) {
	top->clk = 0; top->eval();
	top->clk = 1; top->eval();
}

static void reset(top_ptr top, int n) {
	top->rst = 1;
	while (n -- > 0) single_cycle(top);
	top->rst = 0;
}

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

	nvboard_bind_all_pins(top.get());
	nvboard_init();

	reset(top.get(), 10);

	while(!contextp->gotFinish()) {
		nvboard_update();
#if VM_TRACE_VCD
		contextp->timeInc(1);
		top->clk = 0; top->eval();
		tfp->dump(contextp->time());
		contextp->timeInc(1);
		top->clk = 1; top->eval();
		tfp->dump(contextp->time());
#else
		single_cycle(top.get());
#endif
	}
}

