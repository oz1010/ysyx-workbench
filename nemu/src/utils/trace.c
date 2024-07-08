#include <stdlib.h>
#include <assert.h>
#include "trace.h"
#include "cpu/ifetch.h"
#include "memory/paddr.h"

IRingBuf_t iringbuf;

void insert_before(IRingBufItem_t* pos, IRingBufItem_t* item);
int fmt_instruction(IRingBufItem_t* item, vaddr_t addr);

#ifdef CONFIG_ITRACE

void iringbuf_init()
{
    memset(&iringbuf, 0, sizeof(iringbuf));
    for(int i=0; i<IRINGBUF_ITEM_MAX; ++i)
    {
        IRingBufItem_t* item = malloc(sizeof(IRingBufItem_t));
        assert(item && "No enough memory\n");
        memset(item, 0, sizeof(IRingBufItem_t));

        if (iringbuf.header)
        {
            insert_before(iringbuf.header, item);
        }
        else
        {
            item->next = item;
            item->prev = item;
            iringbuf.header = item;
        }
        ++iringbuf.count;
    }
}

void iringbuf_update(vaddr_t addr, const char* str, bool err)
{
    iringbuf.header = iringbuf.header->next;
    IRingBufItem_t* item = iringbuf.header;
    item->addr = addr;
    strncpy(item->buf, str, sizeof(item->buf) - 1);
    if (err)
        iringbuf.erritem = item;
}

void iringbuf_show()
{
    IRingBufItem_t* item = iringbuf.header;
    IRingBufItem_t* start = item->next;
    IRingBufItem_t* end = start;

    if (!item->addr) {
        printf("No code execute.\n");
        return;
    }

    // 将近期运行过的指令都输出
    printf(ANSI_FMT("Instruction trace:\n",ANSI_FG_GREEN));
    item = start;
    do{
        printf("%s", (item==iringbuf.header?ANSI_FMT("  --> ",ANSI_FG_RED):"      "));
        printf("%s\n", item->buf);
        item = item->next;
    }while(item != end);

    // 找到需要打印的结束处
    IRingBufItem_t next_item;
    item = &next_item;
    vaddr_t addr = iringbuf.header->addr + 4;
    if (IRINGBUF_NEXT_INST_SHOW)
        printf("Instruction next:\n");
    for (int i=0; i<IRINGBUF_NEXT_INST_SHOW; ++i)
    {
        if (fmt_instruction(item, addr)!=0)
            break;
        addr += 4;
        printf("%s", (item==iringbuf.header?ANSI_FMT("  --> ",ANSI_FG_RED):"      "));
        printf("%s\n", item->buf);
    }
}

void insert_before(IRingBufItem_t* pos, IRingBufItem_t* item)
{
    item->prev = pos->prev;
    item->next = pos;
    pos->prev->next = item;
    pos->prev = item;
}

int fmt_instruction(IRingBufItem_t* item, vaddr_t addr)
{
#ifdef CONFIG_ITRACE
  char *p = item->buf;
  p += snprintf(p, sizeof(item->buf), FMT_WORD ":", addr);
  int ilen = 4;
  int i;
  if (unlikely(!in_pmem(addr)))
  {
    return -1;
  }
  int instval = inst_fetch(&addr, 4);
  uint8_t *inst = (uint8_t *)&instval;
  for (i = ilen - 1; i >= 0; i --) {
    p += snprintf(p, 4, " %02x", inst[i]);
  }
  int ilen_max = MUXDEF(CONFIG_ISA_x86, 8, 4);
  int space_len = ilen_max - ilen;
  if (space_len < 0) space_len = 0;
  space_len = space_len * 3 + 1;
  memset(p, ' ', space_len);
  p += space_len;

#ifndef CONFIG_ISA_loongarch32r
  void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
  disassemble(p, item->buf + sizeof(item->buf) - p,
      MUXDEF(CONFIG_ISA_x86, s->snpc, addr), inst, ilen);
  return 0;
#else
  p[0] = '\0'; // the upstream llvm does not support loongarch32r
  return 0;
#endif
#endif
  return -1;
}

#endif
