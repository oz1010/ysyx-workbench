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

typedef struct _mem_item
{
    const char* name;
    paddr_t startaddr;
    paddr_t endaddr; /* 不包含边界 */
    uint8_t* raw_mem;
    struct {
        word_t (*read)(void *mem_item_arg, vaddr_t addr, int len);
        void (*write)(void *mem_item_arg, vaddr_t addr, int len, word_t data);
    };
} mem_item_t;

extern mem_item_t mem_items[];

/* convert the guest physical address in the guest program to host virtual address in NEMU */
uint8_t* guest_to_host(paddr_t paddr);

void init_mem();

word_t paddr_read(paddr_t addr, int len);
void paddr_write(paddr_t addr, int len, word_t data);
const char* size_str(uint32_t size_b);
void show_mem();
mem_item_t* find_mem_item(paddr_t addr);

#endif
