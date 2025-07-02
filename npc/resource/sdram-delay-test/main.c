#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

static inline uint8_t inb(uintptr_t addr)
{
    return *(volatile uint8_t *)addr;
}
static inline uint16_t inw(uintptr_t addr)
{
    return *(volatile uint16_t *)addr;
}
static inline uint32_t inl(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}
static inline uint64_t inll(uintptr_t addr)
{
    return *(volatile uint64_t *)addr;
}
static inline void outb(uintptr_t addr, uint8_t data)
{
    *(volatile uint8_t *)addr = data;
}
static inline void outw(uintptr_t addr, uint16_t data)
{
    *(volatile uint16_t *)addr = data;
}
static inline void outl(uintptr_t addr, uint32_t data)
{
    *(volatile uint32_t *)addr = data;
}

#define CHECK_DATA(type, a, b)                                                  \
    do                                                                          \
    {                                                                           \
        type a_v = (a);                                                         \
        type b_v = (b);                                                         \
        if (a_v != b_v)                                                         \
        {                                                                       \
            printf("error.\n");                                                 \
            printf("current addr: %#x data: %#x check: %#x\n", addr, a_v, b_v); \
            halt((int)b_v);                                                     \
        }                                                                       \
    } while (0)

extern char _heap_start;

#define SDRAM_ADDR 0xa0000000
#define SDRAM_BLK_SIZE 0x02000000
#define SDRAM_BLK_NUM 2
#define SDRAM_SIZE (SDRAM_BLK_NUM * SDRAM_BLK_SIZE)
#define SDRAM_END (SDRAM_ADDR + SDRAM_SIZE)

#define SDRAM_MIX_ADDR ((uint32_t)&_heap_start)
#define SDRAM_MIX_SIZE (SDRAM_SIZE - 4)  // 全域混合测试总大小，避免最后写4字节时超出范围
#define SDRAM_MIX_END (SDRAM_ADDR + SDRAM_MIX_SIZE)
#define SDRAM_MIX_STEP 0x00001000  // 全域混合测试，单步跳转

#define SDRAM_BLK_TEST_ADDR ((uint32_t)&_heap_start)
#define SDRAM_BLK_TEST_SIZE (SDRAM_BLK_NUM * 0x00001000)
#define SDRAM_BLK_TEST_END (SDRAM_BLK_TEST_ADDR + SDRAM_BLK_TEST_SIZE)

#define SDRAM_UNALIGN_TEST_ADDR ((uint32_t)&_heap_start)
#define SDRAM_UNALIGN_TEST_SIZE 0x00000800
#define SDRAM_UNALIGN_TEST_END (SDRAM_UNALIGN_TEST_ADDR + SDRAM_UNALIGN_TEST_SIZE)


int main()
{
    uint32_t addr;

    printf("sdram unalign access - 4Bytes [%#x, %#x) ... ", SDRAM_UNALIGN_TEST_ADDR,
           SDRAM_UNALIGN_TEST_END);
    for (uint32_t offset = 0; offset < 4; ++offset)
    {
        for (addr = SDRAM_UNALIGN_TEST_ADDR + offset; addr < SDRAM_UNALIGN_TEST_END + offset;
             addr += 4)
            outl(addr, addr);
        for (addr = SDRAM_UNALIGN_TEST_ADDR + offset; addr < SDRAM_UNALIGN_TEST_END + offset;
             addr += 4)
            CHECK_DATA(uint32_t, inl(addr), addr);
    }
    printf("done.\n");
    printf("current addr: %#x\n", addr);

    return 0;
}
