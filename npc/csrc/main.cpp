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

#define MEMORY_SIZE (4*1024)

typedef TOP_NAME* top_ptr;

uint32_t memory[MEMORY_SIZE] = {0};
void load_memory(const char* fpath);

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
	uint32_t clk = 1;

	// 上电复位
	top->rst = 1;
	for (int i=0; i<10; ++i) {
		clk = !clk;
		top->clk = clk;
		top->eval();
	}
	top->rst = 0;

	// 加载内存程序
	const uint64_t sim_time = MEMORY_SIZE;
	uint32_t* regs = &top->out_regs[0];
	uint32_t base_addr = regs[32];
	uint32_t data = 0;
	load_memory("build/test/addi/case.bin");

	while(contextp->time()<sim_time && !contextp->gotFinish()) {
		// 模拟从内存读数据
		clk = !clk;
		if (clk) {
			uint32_t idx = regs[32] - base_addr;
			if (idx >= (sizeof(memory)/sizeof(memory[0]))){
				printf("simulator read out of memory\n");
				break;
			}
			data = memory[idx];
			if (!data)
			{
				printf("simulator read NULL memory\n");
				break;
			}
			// printf("=> pc %#x data %#x\n", regs[32], data);
		}
		top->clk = clk;
		top->data = data;

		// printf("pc %#x clk %u data %#x x0 %#x a0 %#x a1 %#x\n", regs[32], clk, data, regs[0], regs[10], regs[11]);
		// 电路仿真
		contextp->timeInc(1);
		top->eval();
		RECORD_TRACE_VCD();
	}

	return 0;
}

void load_memory(const char* fpath)
{
	const char* npc_home = getenv("NPC_HOME");
	assert(npc_home && "Miss set NPC_HOME");

	char file_path[1024] = {0};
	strcat(&file_path[strlen(file_path)], npc_home);
	strcat(&file_path[strlen(file_path)], "/");
	strcat(&file_path[strlen(file_path)], fpath);

	printf("Load memory from file %s\n", file_path);
	size_t membytes = MEMORY_SIZE*sizeof(memory[0]);
	unsigned char* pmemstart = (unsigned char*)&memory[0];
	unsigned char* pmemend = pmemstart + membytes;
	FILE* fd = fopen(file_path, "rb");
	assert(fd && "open file failed");

	size_t readsize = fread(pmemstart, 1, membytes, fd);
	printf("Load memory from file total size %u\n", readsize);
}
