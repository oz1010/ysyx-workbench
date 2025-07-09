#include <string>
#include <vector>
#include <iostream>
#include "util.h"
#include "mem.h"
#include "generated/autoconf.h"

std::vector<mem_info_t> mem_infos = {
    {
        "sram",
        CONFIG_SRAM_BASE,
        CONFIG_SRAM_SIZE,
    },
    {
        "mrom",
        CONFIG_MROM_BASE,
        CONFIG_MROM_SIZE,
    },
    {
        "flash",
        CONFIG_FLASH_BASE,
        CONFIG_FLASH_SIZE,
        4,
        154.375,
    },
    {
        "psram",
        CONFIG_PSRAM_BASE,
        CONFIG_PSRAM_SIZE,
    },
    {
        "sdram",
        CONFIG_SDRAM_BASE,
        CONFIG_SDRAM_SIZE,
        4,
        9.6,
    },
};

int in_mem(uint32_t addr)
{
    for (size_t i = 0; i < mem_infos.size(); ++i)
    {
        // 跳过sram
        if (i == 0)
            continue;

        auto const& mem_info = mem_infos[i];
        if (addr >= mem_info.baseaddr && addr < (mem_info.baseaddr + mem_info.size))
        {
            return i;
        }
    }

    return -1;
}

std::string mem_idx_2_str(uint32_t idx)
{
    if (idx < mem_infos.size())
    {
        return mem_infos[idx].name;
    }
    return "";
}

const mem_info_t& get_mem_info(uint32_t idx)
{
    return mem_infos[idx];
}

void set_mem_time(std::string& name, double access_time, double miss_penalty)
{
    for (auto& mem_info : mem_infos)
    {
        if (mem_info.name == name)
        {
            mem_info.access_time = access_time;
            mem_info.miss_penalty = miss_penalty;
            break;
        }
    }
}

void show_mem_time(void)
{
    std::cout << "存储访问时间：\n";
    for (auto& mem_info : mem_infos)
    {
        std::cout << mem_info.name << ": " << mem_info.access_time << " " << mem_info.miss_penalty
                  << std::endl;
    }
}
