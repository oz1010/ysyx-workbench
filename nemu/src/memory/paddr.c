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
#include <device/mmio.h>
#include <isa.h>
#include <macro.h>

static word_t mem_read(void *mem_item_arg, vaddr_t addr, int len);
static void mem_write(void *mem_item_arg, vaddr_t addr, int len, word_t data);

#if !CONFIG_PMEM_MALLOC
#if CONFIG_MEM_TYPE_MULTI
static uint8_t raw_sdram[CONFIG_SDRAM_SIZE] PG_ALIGN = {};
static uint8_t raw_sram[CONFIG_SRAM_SIZE] PG_ALIGN = {};
static uint8_t raw_mrom[CONFIG_MROM_SIZE] PG_ALIGN = {};
static uint8_t raw_flash[CONFIG_FLASH_SIZE] PG_ALIGN = {};
static uint8_t raw_psram[CONFIG_PSRAM_SIZE] PG_ALIGN = {};
#else
static uint8_t raw_memory[CONFIG_MSIZE] PG_ALIGN = {};
#endif
#endif

// 推荐按地址从小到大排列
mem_item_t mem_items[] = {
#if CONFIG_MEM_TYPE_MULTI
#if CONFIG_SRAM
  {
    .name = "sram",
    .startaddr = CONFIG_SRAM_BASE,
    .endaddr = (CONFIG_SRAM_BASE+CONFIG_SRAM_SIZE),
    .raw_mem = MUXDEF(CONFIG_PMEM_MALLOC, 0, raw_sram),
    .read = mem_read,
    .write = mem_write,
  },
#endif
#if CONFIG_MROM
  {
    .name = "mrom",
    .startaddr = CONFIG_MROM_BASE,
    .endaddr = (CONFIG_MROM_BASE+CONFIG_MROM_SIZE),
    .raw_mem = MUXDEF(CONFIG_PMEM_MALLOC, 0, raw_mrom),
    .read = mem_read,
    .write = mem_write,
  },
#endif
#if CONFIG_FLASH
  {
    .name = "flash",
    .startaddr = CONFIG_FLASH_BASE,
    .endaddr = (CONFIG_FLASH_BASE+CONFIG_FLASH_SIZE),
    .raw_mem = MUXDEF(CONFIG_PMEM_MALLOC, 0, raw_flash),
    .read = mem_read,
    .write = mem_write,
  },
#endif
#if CONFIG_PSRAM
  {
    .name = "psram",
    .startaddr = CONFIG_PSRAM_BASE,
    .endaddr = (CONFIG_PSRAM_BASE+CONFIG_PSRAM_SIZE),
    .raw_mem = MUXDEF(CONFIG_PMEM_MALLOC, 0, raw_psram),
    .read = mem_read,
    .write = mem_write,
  },
#endif
#if CONFIG_SDRAM
  {
    .name = "sdram",
    .startaddr = CONFIG_SDRAM_BASE,
    .endaddr = (CONFIG_SDRAM_BASE+CONFIG_SDRAM_SIZE),
    .raw_mem = MUXDEF(CONFIG_PMEM_MALLOC, 0, raw_sdram),
    .read = mem_read,
    .write = mem_write,
  },
#endif
#else
  {
    .name = "memory",
    .startaddr = CONFIG_MBASE,
    .endaddr = (CONFIG_MBASE+CONFIG_MSIZE),
    .raw_mem = MUXDEF(CONFIG_PMEM_MALLOC, 0, raw_memory),
    .read = mem_read,
    .write = mem_write,
  },
#endif
};

#define out_of_bound(ADDR)                                                        \
    do                                                                            \
    {                                                                             \
        show_mem();                                                               \
        panic("[%s:%d %s] NEMU access address = " FMT_PADDR                       \
          " is out of bound of mem at pc = " FMT_WORD,                            \
          __FILE__, __LINE__, __FUNCTION__, ADDR, cpu.pc);                        \
    } while (0)

uint8_t* guest_to_host(paddr_t paddr) {
  mem_item_t *item = find_mem_item(paddr);
  if (!item) out_of_bound(paddr);
  return item->raw_mem + paddr - item->startaddr;
}

static word_t mem_read(void *mem_item_arg, vaddr_t addr, int len)
{
  mem_item_t *item = (mem_item_t *)mem_item_arg;
  word_t ret = host_read(item->raw_mem + addr - item->startaddr, len);
  return ret;
}
static void mem_write(void *mem_item_arg, vaddr_t addr, int len, word_t data)
{
  mem_item_t *item = (mem_item_t *)mem_item_arg;
  host_write(item->raw_mem + addr - item->startaddr, len, data);
}

const char* size_str(uint32_t size_b) {
  static char str[64];
  uint32_t size_kb = size_b / 1024;
  uint32_t size_mb = size_kb / 1024;
  uint32_t size_gb = size_mb / 1024;

  if (size_gb>0) {
    snprintf(str, sizeof(str), "%uGB", size_gb);
  } else if (size_mb>0) {
    snprintf(str, sizeof(str), "%uMB", size_mb);
  } else if (size_kb>0) {
    snprintf(str, sizeof(str), "%uKB", size_kb);
  }else {
    snprintf(str, sizeof(str), "%uB", size_b);
  }

  return str;
}

void init_mem() {
  for (int idx=0; idx<ARRLEN(mem_items); ++idx) {
    mem_item_t *item = &mem_items[idx];
    uint32_t size = (item->endaddr - item->startaddr);
    int init_val = MUXDEF(CONFIG_MEM_RANDOM, rand(), CONFIG_MEM_INIT_VALUE);
    if (!item->raw_mem) {
      item->raw_mem = (uint8_t *)malloc(size);
      if (!item->raw_mem) {
        Log("Memory item malloc failed, %s [" FMT_PADDR ", " FMT_PADDR ")-%s", item->name, item->startaddr, item->endaddr, size_str(size));
        exit(-1);
      }
    }
      
    memset(item->raw_mem, init_val, size);
    Log("Memory item init success, %s [" FMT_PADDR ", " FMT_PADDR ")-%s initialize value %#x", item->name, item->startaddr, item->endaddr, size_str(size), init_val);
  }
}

void show_mem() {
  raw_all(ANSI_FMT("Memory item info:\n", ANSI_FG_GREEN));
  for (int idx=0; idx<ARRLEN(mem_items); ++idx) {
    mem_item_t *item = &mem_items[idx];
    uint32_t size = (item->endaddr - item->startaddr);
    raw_all("\t%s [" FMT_PADDR ", " FMT_PADDR ")-%s\n", item->name, item->startaddr, item->endaddr, size_str(size));
  }
}

mem_item_t* find_mem_item(paddr_t addr) {
  for (int idx=0; idx<ARRLEN(mem_items); ++idx) {
    mem_item_t *item = &mem_items[idx];
    if (addr < item->endaddr && addr >= item->startaddr) {
      return item;
    }
  }

  return NULL;
}

word_t paddr_read(paddr_t addr, int len) {
  mem_item_t *item = find_mem_item(addr);
  if (likely(item != NULL))
    return item->read(item, addr, len);
  IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
  out_of_bound(addr);
  return 0;
}

void paddr_write(paddr_t addr, int len, word_t data) {
  mem_item_t *item = find_mem_item(addr);
  if (likely(item != NULL))
  {
    item->write(item, addr, len, data);
    return;
  }
  IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
  out_of_bound(addr);
}
