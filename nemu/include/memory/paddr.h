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

#ifndef __MEMORY_PADDR_H__
#define __MEMORY_PADDR_H__

#include <common.h>

#define MEM_SRAM_BASE    0x0f000000
#define MEM_SRAM_SIZE    0x00002000
#define MEM_MROM_BASE    0x20000000
#define MEM_MROM_SIZE    0x00001000
#define MEM_FLASH_BASE   0x30000000
#define MEM_FLASH_SIZE   0x01000000
#define MEM_PSRAM_BASE   0x80000000
#define MEM_PSRAM_SIZE   0x00400000

typedef struct {
  const char *  name;
  paddr_t       startaddr;
  paddr_t       endaddr;    /* 不包含边界 */
  uint8_t *     raw_mem;
} mem_item_t;

extern mem_item_t mem_items[];

/* convert the guest physical address in the guest program to host virtual address in NEMU */
uint8_t* guest_to_host(paddr_t paddr);

word_t paddr_read(paddr_t addr, int len);
void paddr_write(paddr_t addr, int len, word_t data);
word_t rom_read(paddr_t addr, int len);
const char* size_str(uint32_t size_b);
void show_mem();
mem_item_t* find_mem_item(paddr_t addr);

#endif
