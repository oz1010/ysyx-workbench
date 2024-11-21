#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <getopt.h>
#include "Vtop.h"
#include "verilated.h"
#include "isa.h"
#include "dm/cpu_interface.h"
#include "debug.h"
#include "memory/paddr.h"

cpu_opt_t rv_cpu_opt;
CPU_state cpu;

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

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n) {
}

void init_cpu() {
#if CONFIG_DEBUG_MODULE
	// 初始化调试模块
	rv_cpu_opt.get_gpr = rv_get_gpr;
	rv_cpu_opt.access_mem = rv_access_mem;
	dtm_init(&rv_cpu_opt);
#endif
}
