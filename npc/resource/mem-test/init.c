#include <am.h>
#include <npc.h>
#include "klib.h"

extern uint32_t _heap_start;

#define SRAM_TEST_ADDR ((uint32_t)&_heap_start)
#define SDRAM_TEST_ADDR (0xa0000000+0x43210)
#define SDRAM_ADDR 0xa0000000
#define SDRAM_BLK_SIZE 0x02000000
#define SDRAM_BLK_NUM 2
#define SDRAM_SIZE (SDRAM_BLK_NUM * SDRAM_BLK_SIZE)

#define SDRAM_UNALIGN_TEST_ADDR SDRAM_TEST_ADDR
#define SDRAM_UNALIGN_TEST_SIZE 0x000008
#define SDRAM_UNALIGN_TEST_END (SDRAM_UNALIGN_TEST_ADDR + SDRAM_UNALIGN_TEST_SIZE)

#define SDRAM_MIX_ADDR SDRAM_ADDR
#define SDRAM_MIX_SIZE (SDRAM_SIZE - 4)  // 全域混合测试总大小，避免最后写4字节时超出范围
#define SDRAM_MIX_END (SDRAM_MIX_ADDR + SDRAM_MIX_SIZE)
#define SDRAM_MIX_STEP 0x00100000  // 全域混合测试，单步跳转

typedef struct {
  uint32_t addr;
  uint32_t data;
  uint8_t type;  // 读写带宽数据类型
} case_info_t;

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

#if 1
  for (uint32_t offset = 0; offset < 4; ++offset)
  {
    // uint32_t startaddr = SDRAM_UNALIGN_TEST_ADDR + 0x101 * offset;
    // uint32_t endaddr = startaddr + SDRAM_UNALIGN_TEST_SIZE;
    // for (addr=startaddr; addr<endaddr; addr+=4) {
    //   outl(addr, addr);
    // }
    // for (addr=startaddr; addr<endaddr; addr+=4) {
    //   CHECK_DATA(uint32_t, inl(addr), addr);
    // }

    for (addr = SDRAM_UNALIGN_TEST_ADDR + offset; addr < SDRAM_UNALIGN_TEST_END + offset;
          addr += 4)
        outl(addr, addr);
    for (addr = SDRAM_UNALIGN_TEST_ADDR + offset; addr < SDRAM_UNALIGN_TEST_END + offset;
          addr += 4)
        CHECK_DATA(uint32_t, inl(addr), addr);
  }

  // /* 全域混合读写访问检测 */
  // for (addr = SDRAM_MIX_ADDR; addr < SDRAM_MIX_END; addr += SDRAM_MIX_STEP)
  // {
  //     outb(addr, addr);
  //     addr += 1;
  //     outw(addr, addr);
  //     addr += 2;
  //     outl(addr, addr);
  //     addr += 4;
  // }
  // for (addr = SDRAM_MIX_ADDR; addr < SDRAM_MIX_END; addr += SDRAM_MIX_STEP)
  // {
  //     CHECK_DATA(uint8_t, inb(addr), addr);
  //     addr += 1;
  //     CHECK_DATA(uint16_t, inw(addr), addr);
  //     addr += 2;
  //     CHECK_DATA(uint32_t, inl(addr), addr);
  //     addr += 4;
  // }

  // addr = SDRAM_UNALIGN_TEST_ADDR;
  // /* 当数据量为3及以上时，循环不会优化执行命令，会直接执行非对齐4字节指令 */
  // case_info_t infos[] = {
  //   {addr+0x10, 0x10, 1},
  //   {addr+0x11, 0x11, 1},
  //   {addr+0x12, 0x12, 1},
  //   {addr+0x13, 0x13, 1},
  //   {addr+0x20, 0x2120, 2},
  //   {addr+0x21, 0x2221, 2},
  //   {addr+0x22, 0x2322, 2},
  //   {addr+0x23, 0x2423, 2},
  //   {addr+0x40, 0x43424140, 4},
  //   {addr+0x41, 0x44434241, 4},
  //   {addr+0x42, 0x45444342, 4},
  //   {addr+0x43, 0x46454443, 4},
  // };

  // outl(addr+0x10, 0x13121110);
  // outl(addr+0x14, 0x17161514);
  // outl(addr+0x18, 0x1b1a1918);
  // outl(addr+0x20, 0x23222120);
  // outl(addr+0x24, 0x27262524);
  // outl(addr+0x28, 0x2b2a2928);
  // outl(addr+0x40, 0x43424140);
  // outl(addr+0x44, 0x47464544);
  // outl(addr+0x48, 0x4b4a4948);

  // for (uint32_t i=0; i<(sizeof(infos)/sizeof(infos[0])); ++i) {
  //   case_info_t *info = &infos[i];
  //   switch(info->type) {
  //     case 1:
  //       CHECK_DATA(uint8_t, inb(info->addr), info->data);
  //       break;
  //     case 2:
  //       CHECK_DATA(uint16_t, inw(info->addr), info->data);
  //       break;
  //     case 0:
  //     case 4:
  //       CHECK_DATA(uint32_t, inl(info->addr), info->data);
  //       break;

  //     default:
  //       halt(info->addr);
  //       break;
  //   }
  // }

#else
  addr = SDRAM_UNALIGN_TEST_ADDR;
  /* 当数据量为3及以上时，循环不会优化执行命令，会直接执行非对齐4字节指令 */
  case_info_t infos[] = {
    {addr+0x0, 0x33323130},
    {addr+0x5, 0x38373635},
    {addr+0x1, 0x34333231},
    {addr+0x2, 0x35343332},
    {addr+0x3, 0x36353433},
  };
  outl(addr+0x0, 0x33323130);
  outl(addr+0x4, 0x37363534);
  outl(addr+0x8, 0x3b3a3938);

  for (uint32_t i=0; i<(sizeof(infos)/sizeof(infos[0])); ++i) {
    case_info_t *info = &infos[i];
    CHECK_DATA(uint32_t, inl(info->addr), info->data);
  }
  CHECK_DATA(uint32_t, inl(addr+0x1), 0x34333231);
  CHECK_DATA(uint32_t, inl(addr+0x2), 0x35343332);
  CHECK_DATA(uint32_t, inl(addr+0x3), 0x36353433);

#endif

  halt(0);
}
