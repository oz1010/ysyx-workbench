/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <common.h>
#include "dm/cpu_interface.h"
#include "dm/dm_define.h"
#include "memory/vaddr.h"

void init_monitor(int, char *[]);
void am_init_monitor();
void engine_start();
int is_exit_status_bad();
extern int dtm_init(cpu_opt_t *cpu_opt);

static word_t * rv_get_gpr(CPU_state *c, size_t idx)
{
	assert(idx<DM_ARRAY_SIZE(c->gpr) && "get gpr is out of range");
	return &c->gpr[idx];
}

static int rv_access_mem(uint32_t write, uint32_t pc, uint32_t size, uint8_t *data)
{
	const uint32_t addr = pc - CONFIG_MBASE;

  assert(size<=4 && "access memory size is greater than 4");

	if (addr <= CONFIG_MSIZE) {
		// 内存区域
		if (write) {
			vaddr_write(pc, size, *(uint32_t *)data);
		} else {
      word_t mem_val = vaddr_read(pc, size);
      memcpy(data, &mem_val, 4);
		}
	} else {
		LOG_ERROR("%s memory is out of range, pc:%#x addr:%#x size:%u check:%d CONFIG_MSIZE:%u", write?"write":"read", pc, addr, size, (addr <= CONFIG_MSIZE), CONFIG_MSIZE);
		assert(0);
	}

	return 0;
}

int main(int argc, char *argv[]) {
  /* Initialize the monitor. */
#ifdef CONFIG_TARGET_AM
  am_init_monitor();
#else
  init_monitor(argc, argv);
#endif

  /* Start debug module */
  extern CPU_state *cur_cpu;
  extern CPU_state cpu;
  cur_cpu = &cpu;
  cpu_opt_t rv_cpu_opt = {
    .get_gpr = rv_get_gpr,
    .access_mem = rv_access_mem,
  };
  dtm_init(&rv_cpu_opt);

  /* Start engine. */
  engine_start();

  return is_exit_status_bad();
}
