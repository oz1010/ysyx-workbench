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

#include <memory/host.h>
#include <memory/paddr.h>
#include <memory/vmem.h>
#include <device/vdev.h>
#include <isa.h>
#include <macro.h>
#include "generated/autoconf.h"

extern uint8_t *get_vsimu_sram_addr();

static vdev_item_t *mitems[16] = {};
static int mitems_cnt = 0;

#define out_of_bound(ADDR)                                     \
    do                                                         \
    {                                                          \
        show_vdev();                                           \
        panic("[%s:%d %s] NPC access address = " FMT_PADDR     \
              " is out of bound of mem at pc = " FMT_WORD,     \
              __FILE__, __LINE__, __FUNCTION__, ADDR, cpu.pc); \
    } while (0)

uint8_t *guest_to_host(paddr_t paddr)
{
    vdev_item_t *vdev = find_vdev_item(paddr);
    if (!vdev)
        out_of_bound(paddr);
    return vdev->raw_mem + paddr - vdev->startaddr;
}

static void mem_handler(void *item_arg, bool is_write, vaddr_t addr, int len, word_t *data)
{
    vdev_item_t *vdev = (vdev_item_t *)item_arg;
    assert(vdev);

    if (is_write)
    {
        host_write((uint8_t *)vdev->raw_mem + addr - vdev->startaddr, len, *data);
    }
    else
    {
        word_t ret = host_read((uint8_t *)vdev->raw_mem + addr - vdev->startaddr, len);
        *data = ret;
    }
}

const char *size_str(uint32_t size_b)
{
    static char str[64];
    uint32_t size_kb = size_b / 1024;
    uint32_t size_mb = size_kb / 1024;
    uint32_t size_gb = size_mb / 1024;

    if (size_gb > 0)
    {
        snprintf(str, sizeof(str), "%uGB", size_gb);
    }
    else if (size_mb > 0)
    {
        snprintf(str, sizeof(str), "%uMB", size_mb);
    }
    else if (size_kb > 0)
    {
        snprintf(str, sizeof(str), "%uKB", size_kb);
    }
    else
    {
        snprintf(str, sizeof(str), "%uB", size_b);
    }

    return str;
}

void init_mem()
{
    init_vmem();

#if CONFIG_MEM_TYPE_MULTI
#if CONFIG_SRAM
    mitems[mitems_cnt++] =
        add_vdev_item(VDEV_MEM, "sram", CONFIG_SRAM_BASE, get_vsimu_sram_addr(), CONFIG_SRAM_SIZE,
                      (VDEV_ATTR_READ | VDEV_ATTR_WRITE | VDEV_ATTR_EXEC), mem_handler);
#endif
#if CONFIG_MROM
    uint8_t *mrom_space = new_vmem(CONFIG_MROM_SIZE);
    mitems[mitems_cnt++] =
        add_vdev_item(VDEV_MEM, "mrom", CONFIG_MROM_BASE, mrom_space, CONFIG_MROM_SIZE,
                      (VDEV_ATTR_READ | VDEV_ATTR_EXEC), mem_handler);
#endif
#if CONFIG_FLASH
    uint8_t *flash_space = new_vmem(CONFIG_FLASH_SIZE);
    mitems[mitems_cnt++] =
        add_vdev_item(VDEV_MEM, "flash", CONFIG_FLASH_BASE, flash_space, CONFIG_FLASH_SIZE,
                      (VDEV_ATTR_READ | VDEV_ATTR_EXEC), mem_handler);
#endif
#if CONFIG_PSRAM
    uint8_t *psram_space = new_vmem(CONFIG_PSRAM_SIZE);
    mitems[mitems_cnt++] =
        add_vdev_item(VDEV_MEM, "psram", CONFIG_PSRAM_BASE, psram_space, CONFIG_PSRAM_SIZE,
                      (VDEV_ATTR_READ | VDEV_ATTR_WRITE | VDEV_ATTR_EXEC), mem_handler);
#endif
#if CONFIG_SDRAM
    uint8_t *sdram_space = new_vmem(CONFIG_SDRAM_SIZE);
    mitems[mitems_cnt++] =
        add_vdev_item(VDEV_MEM, "sdram", CONFIG_SDRAM_BASE, sdram_space, CONFIG_SDRAM_SIZE,
                      (VDEV_ATTR_READ | VDEV_ATTR_WRITE | VDEV_ATTR_EXEC), mem_handler);
#endif
#else
    uint8_t *memory_space = new_vmem(CONFIG_MSIZE);
    mitems[mitems_cnt++] =
        add_vdev_item(VDEV_MEM, "memory", CONFIG_MBASE, memory_space, CONFIG_MSIZE,
                      (VDEV_ATTR_READ | VDEV_ATTR_WRITE | VDEV_ATTR_EXEC), mem_handler);
#endif

    // 初始化内存
    assert(mitems_cnt < ARRLEN(mitems));
    for (int idx = 0; idx < ARRLEN(mitems); ++idx)
    {
        vdev_item_t *vdev = mitems[idx];
        if (!vdev)
            continue;

        int init_val = MUXDEF(CONFIG_MEM_RANDOM, rand(), CONFIG_MEM_INIT_VALUE);
        uint32_t size = (vdev->endaddr - vdev->startaddr);
        memset(vdev->raw_mem, init_val, size);
        Log("Memory vdev init success, %s [" FMT_PADDR ", " FMT_PADDR ")-%s initialize value %#x",
            vdev->name, vdev->startaddr, vdev->endaddr, size_str(size), init_val);
    }
}

word_t paddr_read(paddr_t addr, int len)
{
    vdev_item_t *vdev = find_vdev_item(addr);
    if (likely(vdev != NULL))
        return vdev_read(vdev, addr, len);
    out_of_bound(addr);
    return 0;
}

void paddr_write(paddr_t addr, int len, word_t data)
{
    vdev_item_t *vdev = find_vdev_item(addr);

    if (likely(vdev != NULL))
    {
        vdev_write(vdev, addr, len, data);
        return;
    }
    out_of_bound(addr);
}
