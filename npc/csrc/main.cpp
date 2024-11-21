#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <getopt.h>
#include "Vtop.h"
#include "verilated.h"
#include "cpu/cpu-exec.h"
#include "memory/paddr.h"
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

FILE *log_fp = NULL;

static char def_img_file[] = "npc/build/test/addi/case.bin";
static char *arg_img_file = NULL;
static char *arg_log_file = NULL;
static int arg_dm_port = MUXDEF(CONFIG_DEBUG_MODULE, CONFIG_DM_PORT, 0);

void init_log(const char *log_file);
int parse_args(int argc, char *argv[]);

static void statistic()
{
  	IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
	#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") "lu"
	Log("host time spent = " NUMBERIC_FMT " us", npc_ctx.timer);
	Log("total guest instructions = " NUMBERIC_FMT, npc_ctx.nr_guest_inst);
	if (npc_ctx.timer > 0) Log("simulation frequency = " NUMBERIC_FMT " inst/s", npc_ctx.nr_guest_inst * 1000000 / npc_ctx.timer);
	else Log("Finish running in less than 1 us and can not calculate the simulation frequency");
}

void assert_fail_msg() {
//   isa_reg_display();
//   statistic();
	LOG_ERROR("assert failed, current pc:%#.8x", cpu.pc);
}

int main(int argc, char** argv) {
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

	/* 软件模块初始化 */
	init_cpu();
	init_memory();

	// 初始化参数
	npc_ctx.state = NPC_RUNNING;
	const uint64_t sim_time = CONFIG_MSIZE;
	uint32_t* regs = &top->out_regs[0];
	uint32_t* pc = &regs[32];
	// uint32_t base_addr = regs[32];
	uint32_t data = 0;
	load_memory(arg_img_file ? arg_img_file : def_img_file);

	while(contextp->time()<sim_time && !contextp->gotFinish() && npc_ctx.state==NPC_RUNNING) {
		// 模拟从内存读数据
		clk = !clk;
		if (clk) {
			data = inst_fetch(*pc);
			if (!data)
			{
				panic("simulator read NULL mem data\n");
				break;
			}
			// LOG_DEBUG("=> pc %#x data %#x\n", regs[32], data);
		}
		cpu.pc = *pc;
		memcpy(&cpu.gpr[0], &regs[0], sizeof(regs[0])*32);

		// LOG_DEBUG("pc %#x clk %u data %#x x0 %#x a0 %#x a1 %#x\n", regs[32], clk, data, regs[0], regs[10], regs[11]);
		if (clk) {
#if CONFIG_DEBUG_MODULE
		  	// read instruction before debug
			data = inst_fetch(*pc);
			dtm_update(DM_EXEC_INST_BEFORE, data, &cpu);

			// read instruction before execution
			data = inst_fetch(*pc);
#else
  			data = inst_fetch(*pc);
#endif
			npc_ctx.nr_guest_inst++;
		}

		uint64_t timer_start = get_time();
		// 电路仿真
		top->clk = clk;
		top->data = data;
		contextp->timeInc(1);
		top->eval();
		RECORD_TRACE_VCD();
		uint64_t timer_end = get_time();
		npc_ctx.timer += timer_end - timer_start;

		IFDEF(CONFIG_DEBUG_MODULE, dtm_update(DM_EXEC_INST_AFTER, data, &cpu));
	}

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

	int good = (npc_ctx.state == NPC_END && npc_ctx.halt_ret == 0 || (npc_ctx.state == NPC_QUIT));

	return !good;
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
