#ifndef __TRACE_H__
#define __TRACE_H__

#include <isa.h>
#include "common/flog.h"

extern FILE *trace_fd;

#define ITRACE_ITEM_MAX 5
#define ITRACE_NEXT_INST_SHOW 3

#ifdef CONFIG_ITRACE
#define ITRACE_UPDATE(addr, str, err) itrace_update(addr, str, err)
#define ITRACE_SHOW() itrace_show()
// #define ITRACE_FILE(s) raw_out_fp(trace_fd, ANSI_FMT("<IT>", ANSI_FG_BLUE) " %s\n", s)
#define ITRACE_FILE(s) raw_out_fp(trace_fd, "<IT> " \
                                            "%s\n", \
                                  s)
#else
#define ITRACE_UPDATE(addr, str, err)
#define ITRACE_SHOW()
#define ITRACE_FILE(s)
#endif

#if CONFIG_DTRACE
#define DTRACE_LOG(fmt, ...) raw_out_fp(trace_fd, fmt "\n", ##__VA_ARGS__)
#define DTRACE_LOG_LIMIT(fmt, ...)                         \
    do                                                     \
    {                                                      \
        if (dtrace_limit_check(map->name, addr, len))      \
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

typedef struct IRingBufItem
{
    vaddr_t addr;
    IFDEF(CONFIG_ITRACE, char buf[128]);
    struct IRingBufItem *next;
    struct IRingBufItem *prev;
} IRingBufItem_t;

typedef struct RingBuf
{
    IRingBufItem_t *erritem;
    int count;
    IRingBufItem_t *header;
} IRingBuf_t;

typedef struct _dtrace_limit_s
{
    paddr_t start_addr;
    paddr_t end_addr;
} dtrace_limit_t;

extern FILE *trace_fd;

void itrace_update(vaddr_t addr, const char *str, bool err);
void itrace_show();

bool dtrace_limit_check(const char *name, paddr_t addr, int len);

void trace_init(void);

#endif
