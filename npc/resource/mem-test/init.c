#include <am.h>
#include <npc.h>
#include "klib.h"

extern uint32_t _heap_start;

#define SRAM_TEST_ADDR ((uint32_t)&_heap_start)
#define SDRAM_TEST_ADDR (0xa0000000+0x43210)

void _test_init() {
  uint32_t addr;
  (void)addr;

//   addr = SRAM_TEST_ADDR;
//   outl(addr     , 0x73727170);
//   outl(addr + 5 , 0x78777675);
//   halt(inl(addr + 5));

//   addr = SDRAM_TEST_ADDR;
//   outl(addr     , 0x73727170);
//   outl(addr + 4 , 0x78777675);
//   halt(inl(addr + 0));

  addr = SDRAM_TEST_ADDR + 0x02000000;
  outl(addr     , 0x73727170);
  outl(addr + 4 , 0x78777675);
  halt(inl(addr + 0));
}
