#pragma once

#include <string>
#include "stdint.h"

typedef struct
{
    std::string name;
    uint32_t baseaddr;
    uint32_t size;
} mem_info_t;

int in_mem(uint32_t addr);
std::string mem_idx_2_str(uint32_t idx);
