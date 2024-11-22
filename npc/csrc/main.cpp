#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <getopt.h>
#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "cpu/cpu-exec.h"
#include "memory/paddr.h"
#include "dm/dtm.h"

FILE *log_fp = NULL;
extern char *cfg_img_file;
char *cfg_log_file = NULL;
int cfg_dm_port = MUXDEF(CONFIG_DEBUG_MODULE, CONFIG_DM_PORT, 0);

void init_log(const char *log_file);
int parse_args(int argc, char *argv[]);

int main(int argc, char** argv) {
	printf("Start NPC ...\n");

	parse_args(argc, argv);
	init_log(cfg_log_file);

	/* 软件模块初始化 */
	init_cpu(argc, argv);
	init_memory();

	cpu_exec(-1);

	return !(npc_ctx.state == NPC_END && npc_ctx.halt_ret == 0 || (npc_ctx.state == NPC_QUIT));
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
      case 'l': cfg_log_file = optarg; break;
	//   case 'p': sscanf(optarg, "%d", &cfg_dm_port); break;
      case 1: cfg_img_file = optarg; return 0;
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
