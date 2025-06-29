#ifndef __PERF_MONITOR_H__
#define __PERF_MONITOR_H__

#include <stdint.h>

typedef struct
{
    uint8_t type : 6;  // 数据类型
#define PERF_MONITOR_TYPE_EVENT 1
#define PERF_MONITOR_TYPE_CODE 2

    uint8_t size : 2;  // 事件类型时间长度，2^n
} perf_monitor_header_t;

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
    };
} perf_monitor_data_t;

#endif
