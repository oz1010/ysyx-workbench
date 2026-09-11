#ifndef __PERF_MONITOR_H__
#define __PERF_MONITOR_H__

#include <stdint.h>
#include "common.h"

enum
{
    PERF_MONITOR_TYPE_INIT,
    PERF_MONITOR_TYPE_EVENT,
    PERF_MONITOR_TYPE_CODE,
    PERF_MONITOR_TYPE_ICACHE,

    PERF_MONITOR_TYPE_COUNT,
};

typedef struct
{
    uint8_t type : 6;  // 数据类型

    uint8_t size : 2;  // 事件类型时间长度，2^n
} perf_monitor_header_t;

typedef union _perf_monitor_icache_data
{
    uint8_t raw_val;
    struct
    {
        uint8_t mem_index : 4;   // 取指存储器索引，参考vdev中的顺序
        uint8_t hit_count : 2;   // 取指命中次数增量
        uint8_t miss_count : 2;  // 取指不命中次数增量
    };
} perf_monitor_icache_data_t;

typedef struct
{
    union
    {
        struct
        {
            perf_monitor_header_t header;
            uint8_t type;  // 事件类型
            union
            {
                uint8_t delta0;   // 1字节长度时间
                uint16_t delta1;  // 2字节长度时间
            };
        } event;

        struct
        {
            perf_monitor_header_t header;
            uint8_t inst;  // 指令码
        } code;

        struct
        {
            perf_monitor_header_t header;
            perf_monitor_icache_data_t d;
        } icache;
    };
} perf_monitor_data_t;

#endif
