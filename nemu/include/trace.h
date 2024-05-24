#ifndef __TRACE_H__
#define __TRACE_H__

#include <isa.h>

#define IRINGBUF_ITEM_MAX 16
#define IRINGBUF_SHOW_SIZE 3
#if (2*IRINGBUF_SHOW_SIZE>IRINGBUF_ITEM_MAX)
#error "IRINGBUF_SHOW_SIZE is out of range"
#endif

#ifdef CONFIG_ITRACE
#define IRINGBUF_INIT() iringbuf_init()
#define IRINGBUF_UPDATE(addr,str,err) iringbuf_update(addr,str,err)
#define IRINGBUF_SHOW() iringbuf_show()
#else
#define IRINGBUF_INIT()
#define IRINGBUF_UPDATE(addr,str,err)
#define IRINGBUF_SHOW()
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

void iringbuf_init();
void iringbuf_update(vaddr_t addr, const char* str, bool err);
void iringbuf_show();

#endif
