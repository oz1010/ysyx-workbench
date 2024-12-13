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

#define out_of_bound(ADDR)                                                                        \
    do                                                                                            \
    {                                                                                             \
        panic("[%s:%d %s] NPC access address = " FMT_PADDR " is out of bound of pmem [" FMT_PADDR \
              ", " FMT_PADDR "] at pc = " FMT_WORD,                                               \
              __FILE__, __LINE__, __FUNCTION__, ADDR, PMEM_LEFT, PMEM_RIGHT, cpu.pc);             \
    } while (0)

uint8_t raw_memory[CONFIG_MSIZE] = {0};

uint8_t* guest_to_host(paddr_t paddr)
{
    return raw_memory + paddr - CONFIG_MBASE;
}
paddr_t host_to_guest(uint8_t* haddr)
{
    return haddr - raw_memory + CONFIG_MBASE;
}

static word_t pmem_read(paddr_t addr, int len)
{
    word_t ret = host_read(guest_to_host(addr), len);
    return ret;
}

static void pmem_write(paddr_t addr, int len, word_t data)
{
    host_write(guest_to_host(addr), len, data);
}

void init_mem()
{
    IFDEF(CONFIG_MEM_RANDOM, memset(raw_memory, rand(), CONFIG_MSIZE));
    LOG_INFO("physical memory area [" FMT_PADDR ", " FMT_PADDR "]", PMEM_LEFT, PMEM_RIGHT);
}

int read_memory(paddr_t addr, int len, void* data)
{
    const uint32_t idx = addr - CONFIG_MBASE;

    if (idx > (ARRAY_SIZE(raw_memory) - len))
    {
        LOG_ERROR("addr:%#.8x is out of range", addr);
        return -1;
    }

    memcpy(data, &raw_memory[idx], len);
    return 0;
}

int write_memory(paddr_t addr, int len, void* data)
{
    const uint32_t idx = addr - CONFIG_MBASE;

    if (idx > (ARRAY_SIZE(raw_memory) - len))
    {
        LOG_ERROR("addr:%#.8x is out of range", addr);
        return -1;
    }

    memcpy(&raw_memory[idx], data, len);
    return 0;
}

word_t paddr_read(paddr_t addr, int len)
{
    if (likely(in_pmem(addr)))
        return pmem_read(addr, len);
    IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
    out_of_bound(addr);
    return 0;
}

void paddr_write(paddr_t addr, int len, word_t data)
{
    if (likely(in_pmem(addr)))
    {
        pmem_write(addr, len, data);
        return;
    }
    IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
    out_of_bound(addr);
}
