#include <am.h>
#include <npc.h>
#include "file/bin_header.h"

DECLARE_BIN_HEADER(bin_header);

extern char _heap_start;
int main(const char *args);

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)

Area heap = RANGE(&_heap_start, PMEM_END);
#ifndef MAINARGS
#define MAINARGS ""
#endif
static const char mainargs[] = MAINARGS;

void putch(char ch) {
  outb(SERIAL_PORT, ch);
}

void halt(int code) {
  npc_trap(code);

  // should not reach here
  while (1);
}

void _trm_init() {
  /* 初始化sram */
  init_sram_with_bin_header(&bin_header);

  int ret = main(mainargs);
  halt(ret);
}
