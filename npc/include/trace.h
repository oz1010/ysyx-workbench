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
 *   - IFU结束记录icache_stat（2bit缓存状态：0无 1命中 2未命中）
 *   - LSU结束记录dcache_stat（2bit缓存状态：0无 1命中 2未命中，写为0）
 *   - IDU结束记录inst_code
 *   - EXU结束记录dnpc
 *   - WBU进入记录1组GPR写(wen/index/data)和2组CSR写(wen/addr/data)
 */
typedef struct
{
    uint64_t tick;                            // 取指tick
    uint32_t pc;                              // 取指的PC值
    uint32_t icache_stat;                     // 指令缓存访问状态：0无 1命中 2未命中
    uint32_t dcache_stat;                     // 数据缓存访问状态：0无 1命中 2未命中（写为0）
    uint32_t mem_index;                       // 存储索引：低bit位为指令存储索引（IFU结束时更新），
                                              // 高bit位为数据存储索引；无存储数据时默认为全1，解析显示为none
    uint32_t inst_valid;                      // 指令有效标识，WBU完成时pos==record为有效
    uint32_t inst_code;                       // 指令码
    uint32_t dnpc;                            // 目标跳转的PC值
    uint32_t gpr_wen;                         // GPR写使能，WBU进入时采集
    uint32_t gpr_windex;                      // GPR写索引
    uint32_t gpr_wdata;                       // GPR写数据
    uint32_t csr_wen[2];                      // CSR写使能（2组写通道）
    uint32_t csr_waddr[2];                    // CSR写地址
    uint32_t csr_wdata[2];                    // CSR写数据
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
    int storage_cnt;  // 存储体列表数量（STORAGE），决定存储索引占用的bit位数
} hw_monitor_ctx_t;

extern FILE* trace_fd;

void itrace_update(vaddr_t addr, const char* str, bool err);
void itrace_show();

bool dtrace_limit_check(const char* name, paddr_t addr, int len);

void trace_init(void);

#endif
