#ifndef __TRACE_H__
#define __TRACE_H__

#include <isa.h>
#include "common/flog.h"
#include "common/list.h"
#include "recorder_types.h"

extern FILE* trace_fd;

#define ITRACE_ITEM_MAX 5
#define ITRACE_NEXT_INST_SHOW 3
#define HW_MONITOR_ID_COUNT 6
#define HW_MONITOR_CODE_COUNT 56

#ifdef CONFIG_ITRACE
#define ITRACE_UPDATE(addr, str, err) itrace_update(addr, str, err)
#define ITRACE_SHOW() itrace_show()
// #define ITRACE_FILE(s) raw_out_fp(trace_fd, ANSI_FMT("<IT>", ANSI_FG_BLUE) " %s\n", s)
#define ITRACE_FILE(s)   \
    raw_out_fp(trace_fd, \
               "<IT> "   \
               "%s\n",   \
               s)
#else
#define ITRACE_UPDATE(addr, str, err)
#define ITRACE_SHOW()
#define ITRACE_FILE(s)
#endif

#if CONFIG_DTRACE
#define DTRACE_LOG(fmt, ...) raw_out_fp(trace_fd, fmt "\n", ##__VA_ARGS__)
#define DTRACE_LOG_LIMIT(fmt, ...)                                 \
    do                                                             \
    {                                                              \
        if (dtrace_limit_check(map->name, addr, len))              \
            raw_out_fp(trace_fd, "<DT> " fmt "\n", ##__VA_ARGS__); \
    } while (false)
#else
#define DTRACE_LOG(fmt, ...)
#define DTRACE_LOG_LIMIT(fmt, ...)
#endif

#if CONFIG_ETRACE
#define ETRACE_LOG(fmt, ...) raw_out_fp(trace_fd, "<ET> " fmt "\n", ##__VA_ARGS__)
#else
#define ETRACE_LOG(fmt, ...)
#endif

#if CONFIG_MTRACE
#define MTRACE_ADD(fmt, ...) raw_out_fp(trace_fd, "<MT> " fmt "\n", ##__VA_ARGS__)
#else
#define MTRACE_ADD(fmt, ...)
#endif

/**
 * 本地记录原始数据
 *   - pc作为各阶段的key
 *   - 每阶段需要采集起止tick值
 * 额外记录值
 *   - IFU结束记录icache_miss
 *   - LSU结束记录dcache_miss
 *   - IDU结束记录inst_code
 *   - EXU结束记录dnpc
 */
typedef struct
{
    uint64_t tick;                            // 取指tick
    uint32_t pc;                              // 取指的PC值
    uint32_t icache_miss;                     // 指令缓存miss标识
    uint32_t dcache_miss;                     // 数据缓存miss标识
    uint32_t inst_code;                       // 指令码
    uint32_t dnpc;                            // 目标跳转的PC值
    uint64_t stage_ticks[STAGE_COUNT][2];     // 各阶段执行tick值，每个阶段两个值0--begin 1--end
    list_head_t node;                         // 列表节点
} hw_monitor_rc_raw_data_t;

typedef struct IRingBufItem
{
    vaddr_t addr;
    IFDEF(CONFIG_ITRACE, char buf[128]);
    struct IRingBufItem* next;
    struct IRingBufItem* prev;
} IRingBufItem_t;

typedef struct RingBuf
{
    IRingBufItem_t* erritem;
    int count;
    IRingBufItem_t* header;
} IRingBuf_t;

typedef struct _dtrace_limit_s
{
    paddr_t start_addr;
    paddr_t end_addr;
} dtrace_limit_t;

typedef struct
{
    const char* name;
    uint64_t cnt;
} hw_monitor_item_t;

typedef struct
{
    hw_monitor_item_t events[HW_MONITOR_ID_COUNT];
    hw_monitor_item_t codes[HW_MONITOR_CODE_COUNT];
    rc_bin_descript_t bin_descript;
    list_head_t record_head;
} hw_monitor_ctx_t;

extern FILE* trace_fd;

void itrace_update(vaddr_t addr, const char* str, bool err);
void itrace_show();

bool dtrace_limit_check(const char* name, paddr_t addr, int len);

void trace_init(void);

#endif
