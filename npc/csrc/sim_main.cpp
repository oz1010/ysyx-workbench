#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include "Vtop.h"
#include "verilated.h"
//#include "verilated_fst_c.h"


int main(int argc, char** argv)
{
	// Create logs directory in case we have traces to put under it
	Verilated::mkdir("logs");

	const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
	contextp->debug(0); // Set debug level, 0 is off, 9 is highest
	contextp->randReset(2); // Randomization reset policy
	contextp->traceEverOn(true); // Verilator must compute traced signals
	contextp->commandArgs(argc, argv); // Pass arguments so Verilated code can see them
	
	// "TOP" will be hierarchical name of the module.
	const std::unique_ptr<Vtop> top{new Vtop{contextp.get(), "TOP"}};

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
	}

	top->final();
	// tfp->close();

	// Coverage analysis
#if VM_COVERAGE
	Verilated::mkdir("logs");
	contextp->converagep()->write("logs/coverage.dat");
#endif

	// delete top;
	// delete contextp;
	//
	
	// Final simulation summary
	contextp->statsPrintSummary();

	return 0;
}
