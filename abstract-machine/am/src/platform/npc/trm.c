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
  // /* 初始化sram */
  // uint32_t data_load = (uint32_t)bin_header.data_load;
  // uint32_t data_start = (uint32_t)bin_header.data_start;
  // uint32_t bss_start = (uint32_t)bin_header.bss_start;
  // // *(volatile uint32_t *)(0x0f000ff0) = data_load;
  // // *(volatile uint32_t *)(0x0f000ff4) = data_start;
  // // *(volatile uint32_t *)(0x0f000ff8) = bss_start;
  // // halt(1);
  // for (; data_start < bin_header.data_end; data_start += 4, data_load += 4)
  // {
  //     uint32_t data = *(volatile uint32_t *)data_load;
  //     *(volatile uint32_t *)data_start = data;
  // }
  // for (; bss_start < bin_header.bss_end; bss_start += 4)
  // {
  //     *(uint32_t *)bss_start = 0;
  // }

  int ret = main(mainargs);
  halt(ret);
}
