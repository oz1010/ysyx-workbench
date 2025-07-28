#include <am.h>
#include <npc.h>
#include "klib.h"

extern uint32_t _heap_start;

#define SRAM_TEST_ADDR ((uint32_t)&_heap_start)
#define SDRAM_TEST_ADDR (0xa0000000+0x43210)
#define SDRAM_ADDR 0xa0000000

#define SDRAM_UNALIGN_TEST_ADDR SDRAM_TEST_ADDR
#define SDRAM_UNALIGN_TEST_SIZE 0x000008
#define SDRAM_UNALIGN_TEST_END (SDRAM_UNALIGN_TEST_ADDR + SDRAM_UNALIGN_TEST_SIZE)

#define CHECK_DATA(type, a, b)                                                  \
    do                                                                          \
    {                                                                           \
        type a_v = (a);                                                         \
        type b_v = (b);                                                         \
        if (a_v != b_v)                                                         \
        {                                                                       \
            halt((int)b_v);                                                     \
        }                                                                       \
    } while (0)

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

  // uint32_t addr0 = SDRAM_TEST_ADDR;
  // uint32_t addr1 = SDRAM_TEST_ADDR + 0x02000000;
  // outl(addr0 + 0 , 0x78770123);
  // outl(addr0 + 0x100 , 0x78771234);
  // outl(addr0 + 0x01000000 , 0x78772345);
  // outl(addr1 + 0 , 0x88770123);
  // outl(addr1 + 0x100 , 0x88771234);
  // outl(addr1 + 0x01000000 , 0x88772345);
  // halt(inl(addr1 + 0));

  for (uint32_t offset = 0; offset < 4; ++offset)
  {
      for (addr = SDRAM_UNALIGN_TEST_ADDR + offset; addr < SDRAM_UNALIGN_TEST_END + offset;
            addr += 4)
          outl(addr, addr);
      for (addr = SDRAM_UNALIGN_TEST_ADDR + offset; addr < SDRAM_UNALIGN_TEST_END + offset;
            addr += 4)
          CHECK_DATA(uint32_t, inl(addr), addr);
  }

  halt(0);
}
