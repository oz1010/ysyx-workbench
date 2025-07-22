#include <am.h>
#include <npc.h>
#include "klib.h"

extern uint32_t _heap_start;

#define SRAM_TEST_ADDR ((uint32_t)&_heap_start)

void _test_init() {
  uint32_t addr = SRAM_TEST_ADDR;
  outl(addr     , 0x73727170);
  outl(addr + 5 , 0x78777675);
  halt(inl(addr + 5));
}
