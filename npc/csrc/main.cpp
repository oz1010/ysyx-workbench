#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <getopt.h>
#include "Vtop.h"
#include "verilated.h"

#include "dm/dtm.h"

#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
static void record_trace_vcd(VerilatedVcdC* tfp, VerilatedContext* contextp) {
	tfp->dump(contextp->time());
}
#define RECORD_TRACE_VCD() record_trace_vcd(tfp.get(), contextp.get())
#else
#define RECORD_TRACE_VCD()
#endif

uint8_t memory[CONFIG_MSIZE] = {0};
void load_memory(const char* fpath);

cpu_opt_t rv_cpu_opt;
CPU_state rv_cpu_list[1];
extern CPU_state *cur_cpu;
FILE *log_fp = NULL;

static char def_img_file[] = "npc/build/test/addi/case.bin";
static char *arg_img_file = NULL;
static char *arg_log_file = NULL;
static int arg_dm_port = MUXDEF(CONFIG_DEBUG_MODULE, CONFIG_DM_PORT, 0);

void init_log(const char *log_file);
int parse_args(int argc, char *argv[]);

static word_t * rv_get_gpr(CPU_state *c, size_t idx)
{
	assert(idx<DM_ARRAY_SIZE(c->gpr) && "get gpr is out of range");
	return &c->gpr[idx];
}
static int rv_access_mem(uint32_t write, uint32_t pc, uint32_t size, uint8_t *data)
{
	const uint32_t addr = pc - CONFIG_MBASE;

	if (addr <= CONFIG_MSIZE) {
		// 内存区域
		if (write) {
			memcpy(&memory[addr], data, size);
		} else {
			memcpy(data, &memory[addr], size);
		}
	} else {
		LOG_ERROR("%s memory is out of range, pc:%#x addr:%#x size:%u check:%d CONFIG_MSIZE:%u", write?"write":"read", pc, addr, size, (addr <= CONFIG_MSIZE), CONFIG_MSIZE);
		assert(0);
	}

	return 0;
}
static uint32_t inst_fetch(vaddr_t pc)
{
	const uint32_t addr = pc - CONFIG_MBASE;
	Assert(addr<DM_ARRAY_SIZE(memory), "pc:%#.8x is out of range", pc);

	return *(uint32_t *)&memory[addr];
}

void assert_fail_msg() {
//   isa_reg_display();
//   statistic();
	LOG_ERROR("assert failed, current pc:%#.8x", cur_cpu->pc);
}

int main(int argc, char** argv) {
	cur_cpu = &rv_cpu_list[0];

	parse_args(argc, argv);

	LOG_INFO("Start NPC ...");

	init_log(arg_log_file);

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
	LOG_INFO("Start trace ...\n");
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

	// 输入需要仿真的程序位置
	// char bin_path[256] = {0};
	// size_t bin_path_size = 0;
	// LOG_INFO("Input bin file path (default: %s):\n", def_img_file);
	// char input_c;
	// while(bin_path_size<(sizeof(bin_path)-1) && (input_c = getchar())!='\n')
	// 	bin_path[bin_path_size++] = input_c;
	// bin_path[bin_path_size]='\0';

#if CONFIG_DEBUG_MODULE
	// 初始化调试模块
	rv_cpu_opt.get_gpr = rv_get_gpr;
	rv_cpu_opt.access_mem = rv_access_mem;
	dtm_init(&rv_cpu_opt);
#endif

	// 初始化参数
	const uint64_t sim_time = CONFIG_MSIZE;
	uint32_t* regs = &top->out_regs[0];
	uint32_t* pc = &regs[32];
	// uint32_t base_addr = regs[32];
	uint32_t data = 0;
	load_memory(arg_img_file ? arg_img_file : def_img_file);

	while(contextp->time()<sim_time && !contextp->gotFinish()) {
		// 模拟从内存读数据
		clk = !clk;
		if (clk) {
			// uint32_t idx = regs[32] - base_addr;
			// if (idx >= (sizeof(memory)/sizeof(memory[0]))){
			// 	LOG_INFO("simulator read out of memory\n");
			// 	break;
			// }
			// data = *((uint32_t*)&memory[idx]);
			data = inst_fetch(*pc);
			if (!data)
			{
				panic("simulator read NULL memory\n");
				break;
			}
			// LOG_DEBUG("=> pc %#x data %#x\n", regs[32], data);
		}
		cur_cpu->pc = *pc;
		memcpy(&cur_cpu->gpr[0], &regs[0], sizeof(regs[0])*32);

		// LOG_DEBUG("pc %#x clk %u data %#x x0 %#x a0 %#x a1 %#x\n", regs[32], clk, data, regs[0], regs[10], regs[11]);
		if (clk) {
#if CONFIG_DEBUG_MODULE
		  	// read instruction before debug
			data = inst_fetch(*pc);
			dtm_update(DM_EXEC_INST_BEFORE, data, cur_cpu);

			// read instruction before execution
			data = inst_fetch(*pc);
#else
  			data = inst_fetch(*pc);
#endif
		}

		// 电路仿真
		top->clk = clk;
		top->data = data;
		contextp->timeInc(1);
		top->eval();
		RECORD_TRACE_VCD();

		IFDEF(CONFIG_DEBUG_MODULE, dtm_update(DM_EXEC_INST_AFTER, data, cur_cpu));
	}

	return 0;
}

void load_memory(const char* fpath)
{
	char file_path[1024] = {0};

	if (fpath[0]!='/')
	{
		const char* npc_home = getenv("NPC_HOME");
		Assert(npc_home, "Miss set NPC_HOME");
		strcat(&file_path[strlen(file_path)], npc_home);
		strcat(&file_path[strlen(file_path)], "/../");
	}
	strcat(&file_path[strlen(file_path)], fpath);

	LOG_INFO("Load memory from file %s", file_path);
	size_t membytes = CONFIG_MSIZE*sizeof(memory[0]);
	unsigned char* pmemstart = (unsigned char*)&memory[0];
	unsigned char* pmemend = pmemstart + membytes;
	FILE* fd = fopen(file_path, "rb");
	Assert(fd, "open file:%s failed", file_path);

	size_t readsize = fread(pmemstart, 1, membytes, fd);
	LOG_INFO("Load memory from file total size %lu", readsize);
}

int parse_args(int argc, char *argv[]) {
  const struct option table[] = {
    // {"port"     , required_argument, NULL, 'p'},
    {"log"      , required_argument, NULL, 'l'},
    {"help"     , no_argument      , NULL, 'h'},
    {0          , 0                , NULL,  0 },
  };
  int o;
  while ( (o = getopt_long(argc, argv, "-hl:", table, NULL)) != -1) {
    switch (o) {
      case 'l': arg_log_file = optarg; break;
	//   case 'p': sscanf(optarg, "%d", &arg_dm_port); break;
      case 1: arg_img_file = optarg; return 0;
      default:
        printf("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
        printf("\t-l,--log=FILE           output log to FILE\n");
        // printf("\t-p,--port=PORT          run DM with port PORT\n");
        printf("\n");
        exit(0);
    }
  }
  return 0;
}

void init_log(const char *log_file) {
  log_fp = stdout;
  if (log_file != NULL) {
    FILE *fp = fopen(log_file, "w");
    Assert(fp, "Can not open '%s'", log_file);
    log_fp = fp;
  }
  LOG_INFO("Log is written to %s", log_file ? log_file : "stdout");
}
