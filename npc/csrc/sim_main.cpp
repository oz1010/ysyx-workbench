#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include "Vtop.h"
#include "verilated.h"

#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
#endif

int main(int argc, char** argv)
{
	const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
	contextp->debug(0); // Set debug level, 0 is off, 9 is highest
	contextp->randReset(2); // Randomization reset policy
	contextp->commandArgs(argc, argv); // Pass arguments so Verilated code can see them
	
	// "TOP" will be hierarchical name of the module.
	const std::unique_ptr<Vtop> top{new Vtop{contextp.get(), "TOP"}};

#if VM_TRACE_VCD
	Verilated::mkdir("logs");
	contextp->traceEverOn(true); // Verilator must compute traced signals
	const std::unique_ptr<VerilatedVcdC>tfp{new VerilatedVcdC};
	top->trace(tfp.get(), 99); // Trace 99 levels of hierarchy (or see below)
	tfp->open("logs/simu_top.vcd");
	printf("Start trace ...\n");
#endif

	uint64_t sim_time = 10000;
	while(contextp->time()<sim_time && !contextp->gotFinish())
	{
		contextp->timeInc(1);

		int a = rand() & 1;		
		int b = rand() & 1;		
		top->a = a;
		top->b = b;
		top->eval();
		// printf("a = %d, b = %d, f = %d, time = %lu\n", a, b, top->f, contextp->time());
		assert(top->f == (a ^ b));

#if VM_TRACE_VCD
		tfp->dump(contextp->time());
#endif
	}

	top->final();

	// Coverage analysis
#if VM_COVERAGE
	Verilated::mkdir("logs");
	contextp->converagep()->write("logs/coverage.dat");
#endif

	// Final simulation summary
	contextp->statsPrintSummary();

	return 0;
}
