#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include "memory/paddr.h"
#include "memory/vaddr.h"
#include "dm/dtm.h"
#include "utils.h"

void init_monitor(int argc, char *argv[]);
void am_init_monitor();
void engine_start();
int is_exit_status_bad();
void exit_vsimu();

word_t *rv_get_gpr(CPU_state *c, size_t idx)
{
    assert(idx < DM_ARRAY_SIZE(c->gpr) && "get gpr is out of range");
    return &c->gpr[idx];
}

int rv_access_mem(uint32_t write, uint32_t pc, uint32_t size, uint8_t *data)
{
    assert(size <= 4 && "access memory size is greater than 4");
    mem_item_t *mem_item = find_mem_item(pc);

    if (mem_item)
    {
        // 内存区域
        if (write)
        {
            mem_item->write(mem_item, pc, size, *(uint32_t *)data);
        }
        else
        {
            word_t mem_val = mem_item->read(mem_item, pc, size);
            memcpy(data, &mem_val, 4);
        }
    }
    else
    {
        show_mem();
        LOG_ERROR("%s memory is out of range, pc:%#x size:%u", write ? "write" : "read", pc, size);
        assert(0);
    }

    return 0;
}

int main(int argc, char **argv)
{
    printf("Start NPC ...\n");

    /* Initialize the monitor. */
#ifdef CONFIG_TARGET_AM
    am_init_monitor();
#else
    init_monitor(argc, argv);
#endif

#if CONFIG_DEBUG_MODULE
    // 初始化调试模块
    extern CPU_state *cur_cpu;
    extern CPU_state cpu;
    cur_cpu = &cpu;
    cpu_opt_t rv_cpu_opt = {
        .get_gpr = rv_get_gpr,
        .access_mem = rv_access_mem,
    };
    dtm_init(&rv_cpu_opt);
#endif

    /* Start engine. */
    engine_start();

    /* Exit vsimu */
    exit_vsimu();

    return is_exit_status_bad();
}
