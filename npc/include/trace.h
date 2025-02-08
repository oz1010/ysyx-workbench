#ifndef __TRACE_H__
#define __TRACE_H__

#include <isa.h>
#include "common/flog.h"

#define IRINGBUF_ITEM_MAX 5
#define IRINGBUF_NEXT_INST_SHOW 3

#ifdef CONFIG_ITRACE
#define IRINGBUF_UPDATE(addr,str,err) iringbuf_update(addr,str,err)
#define IRINGBUF_SHOW() iringbuf_show()
#else
#define IRINGBUF_UPDATE(addr,str,err)
#define IRINGBUF_SHOW()
#endif

#if CONFIG_DTRACE
#define DTRACE_LOG(fmt, ...) flog_printf(trace_fd, fmt "\n", ##__VA_ARGS__)
#define DTRACE_LOG_LIMIT(fmt, ...) do\
  {\
    if (dtrace_limit_check(map->name, addr, len)) \
      flog_printf(trace_fd, fmt "\n", ##__VA_ARGS__);\
  } while (false)
#else
#define DTRACE_LOG(fmt, ...)
#define DTRACE_LOG_LIMIT(fmt, ...)
#endif

typedef struct IRingBufItem {
  vaddr_t addr;
  IFDEF(CONFIG_ITRACE, char buf[128]);
  struct IRingBufItem* next;
  struct IRingBufItem* prev;
} IRingBufItem_t;

typedef struct RingBuf {
  IRingBufItem_t *erritem;
  int count;
  IRingBufItem_t *header;
} IRingBuf_t;

typedef struct _dtrace_limit_s {
  paddr_t start_addr;
  paddr_t end_addr;
} dtrace_limit_t;

extern FILE *trace_fd;

void iringbuf_update(vaddr_t addr, const char* str, bool err);
void iringbuf_show();

bool dtrace_limit_check(const char *name, paddr_t addr, int len);

void trace_init(void);

#endif
