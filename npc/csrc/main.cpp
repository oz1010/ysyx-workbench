#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include "cpu/cpu-exec.h"
#include "memory/paddr.h"
#include "dm/dtm.h"
#include "utils.h"

void init_monitor(int argc, char* argv[]);
void sdb_mainloop();
word_t * rv_get_gpr(CPU_state *c, size_t idx);
int rv_access_mem(uint32_t write, uint32_t pc, uint32_t size, uint8_t *data);
int is_exit_status_bad();

int main(int argc, char** argv)
{
    printf("Start NPC ...\n");

    init_monitor(argc, argv);

#if CONFIG_DEBUG_MODULE
    // 初始化调试模块
    extern CPU_state* cur_cpu;
    extern CPU_state cpu;
    cur_cpu = &cpu;
    cpu_opt_t rv_cpu_opt = {
        .get_gpr = rv_get_gpr,
        .access_mem = rv_access_mem,
    };
    dtm_init(&rv_cpu_opt);
#endif

#ifdef CONFIG_TARGET_AM
    cpu_exec(-1);
#else
    /* Receive commands from user. */
    sdb_mainloop();
#endif

    return is_exit_status_bad();
}
