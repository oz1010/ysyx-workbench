#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"
#include "isa.h"

/**
 * ref. https://chromitem-soc.readthedocs.io/en/latest/clint.html
 */

extern hw_cpu_stat_t hw_cpu_stat;

static uint8_t *clint_base = NULL;
static const uint32_t clint_size = 64 * 1024;
static uint64_t *clint_mtime = NULL;
static hw_time_info_t *clint_time_info = NULL;

static void clint_handler(void *item_arg, bool is_write, vaddr_t addr, int len, word_t *data)
{
    static uint64_t last_tick = 0;
    static uint64_t update_ticks = 10240;

    vdev_item_t *vdev = (vdev_item_t *)item_arg;
    assert(vdev);

    // 触发clint进行更新
    if ((addr == 0x02000048 || addr == 0x02000050) && ((hw_cpu_stat.counts[HW_CPU_STAT_TICK] - last_tick) >= update_ticks))
    {
        last_tick += update_ticks;
        *clint_mtime = get_time();
        get_hw_time_info(clint_time_info);
    }
}

void init_clint()
{
    clint_base = new_vmem(clint_size);
    add_vdev_item(VDEV_EXTER, "clint", CONFIG_CLINT_BASE_ADDR, clint_base, clint_size, (VDEV_ATTR_READ|VDEV_ATTR_WRITE),
                  clint_handler);

    // 初始化寄存器
    clint_mtime = (uint64_t *)(clint_base + 0x48);
    clint_time_info = (hw_time_info_t *)(clint_base + 0x50);
    *clint_mtime = get_time();
    get_hw_time_info(clint_time_info);
}
