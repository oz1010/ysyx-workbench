#pragma once

#include <string>
#include "stdint.h"

typedef struct
{
    std::string name;
    uint32_t baseaddr;
    uint32_t size;
    double access_time; // 缓存命中时，访问所需时间
    double miss_penalty; // 缓存未命中时，访问所需时间（扣除缓存返回时间）
} mem_info_t;

int in_mem(uint32_t addr);
std::string mem_idx_2_str(uint32_t idx);
const mem_info_t& get_mem_info(uint32_t idx);
void set_mem_time(std::string& name, double access_time, double miss_penalty);
void show_mem_time(void);
