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

typedef struct
{
    uint32_t addr;
    uint32_t data;
    uint8_t type;  // 读写带宽数据类型
} case_info_t;

#define CHECK_DATA(type, a, b)                                                                  \
    do                                                                                          \
    {                                                                                           \
        type a_v = (a);                                                                         \
        type b_v = (b);                                                                         \
        if (a_v != b_v)                                                                         \
        {                                                                                       \
            printf("error.\n");                                                                 \
            printf("current addr: %#x data: %#x check: %#x type: " #type "\n", addr, a_v, b_v); \
            halt((int)b_v);                                                                     \
        }                                                                                       \
    } while (0)
#define UPDATE_INFOS(INFOS)                                               \
    do                                                                    \
    {                                                                     \
        for (uint32_t i = 0; i < (sizeof(INFOS) / sizeof(INFOS[0])); ++i) \
        {                                                                 \
            case_info_t *info = &INFOS[i];                                \
            addr = info->addr;                                            \
            switch (info->type)                                           \
            {                                                             \
                case (1):                                                 \
                    outb(info->addr, info->data);                         \
                    break;                                                \
                case (2):                                                 \
                    outw(info->addr, info->data);                         \
                    break;                                                \
                case (4):                                                 \
                    outl(info->addr, info->data);                         \
                    break;                                                \
                default:                                                  \
                    printf("unknown info type %d\n", info->type);         \
                    halt(-1);                                             \
            }                                                             \
        }                                                                 \
    } while (0)
#define CHECK_INFOS(INFOS)                                                \
    do                                                                    \
    {                                                                     \
        for (uint32_t i = 0; i < (sizeof(INFOS) / sizeof(INFOS[0])); ++i) \
        {                                                                 \
            case_info_t *info = &INFOS[i];                                \
            addr = info->addr;                                            \
            switch (info->type)                                           \
            {                                                             \
                case (1):                                                 \
                    CHECK_DATA(uint8_t, inb(info->addr), info->data);     \
                    break;                                                \
                case (2):                                                 \
                    CHECK_DATA(uint16_t, inw(info->addr), info->data);    \
                    break;                                                \
                case (4):                                                 \
                    CHECK_DATA(uint32_t, inl(info->addr), info->data);    \
                    break;                                                \
                default:                                                  \
                    printf("unknown info type %d\n", info->type);         \
                    halt(-1);                                             \
            }                                                             \
        }                                                                 \
    } while (0)

#define SDRAM_ADDR 0xa0000000
#define SDRAM_BLK_SIZE 0x02000000
#define SDRAM_BLK_NUM 2
#define SDRAM_SIZE (SDRAM_BLK_NUM * SDRAM_BLK_SIZE)
#define SDRAM_END (SDRAM_ADDR + SDRAM_SIZE)

#define SDRAM_MIX_ADDR SDRAM_ADDR
#define SDRAM_MIX_SIZE (SDRAM_SIZE - 4)  // 全域混合测试总大小，避免最后写4字节时超出范围
#define SDRAM_MIX_END (SDRAM_MIX_ADDR + SDRAM_MIX_SIZE)
#define SDRAM_MIX_STEP 0x00010000  // 全域混合测试，单步跳转

#define SDRAM_BLK_TEST_ADDR SDRAM_ADDR
#define SDRAM_BLK_TEST_SIZE (SDRAM_BLK_NUM * 0x00001000)
#define SDRAM_BLK_TEST_END (SDRAM_BLK_TEST_ADDR + SDRAM_BLK_TEST_SIZE)

#define SDRAM_UNALIGN_TEST_ADDR SDRAM_ADDR
#define SDRAM_UNALIGN_TEST_SIZE 0x00000800
#define SDRAM_UNALIGN_TEST_END (SDRAM_UNALIGN_TEST_ADDR + SDRAM_UNALIGN_TEST_SIZE)

#define SDRAM_TEST_ADDR SDRAM_ADDR

int main()
{
    uint32_t addr = SDRAM_ADDR;

    /* 全域混合读写访问检测 */
    case_info_t winfos[] = {
        {SDRAM_TEST_ADDR + 0x10, 0x10, 1},       {SDRAM_TEST_ADDR + 0x11, 0x11, 1},
        {SDRAM_TEST_ADDR + 0x12, 0x12, 1},       {SDRAM_TEST_ADDR + 0x13, 0x13, 1},
        {SDRAM_TEST_ADDR + 0x20, 0x2120, 2},     {SDRAM_TEST_ADDR + 0x21, 0x2221, 2},
        {SDRAM_TEST_ADDR + 0x22, 0x2322, 2},     {SDRAM_TEST_ADDR + 0x23, 0x2423, 2},
        {SDRAM_TEST_ADDR + 0x40, 0x43424140, 4}, {SDRAM_TEST_ADDR + 0x41, 0x44434241, 4},
        {SDRAM_TEST_ADDR + 0x42, 0x45444342, 4}, {SDRAM_TEST_ADDR + 0x43, 0x46454443, 4},
        {SDRAM_TEST_ADDR + 0xa0, 0xa3a2a1a0, 4}, {SDRAM_TEST_ADDR + 0xa4, 0xa7a6a5a4, 4},
        {SDRAM_TEST_ADDR + 0xa8, 0xabaaa9a8, 4}, {SDRAM_TEST_ADDR + 0xac, 0xafaeadac, 4},
        {SDRAM_TEST_ADDR + 0xb0, 0xb3b2b1b0, 4}, {SDRAM_TEST_ADDR + 0xb4, 0xb7b6b5b4, 4},
        {SDRAM_TEST_ADDR + 0xb8, 0xbbbab9b8, 4}, {SDRAM_TEST_ADDR + 0xbc, 0xbfbebdbc, 4},
    };
    case_info_t rinfos[] = {
        {SDRAM_TEST_ADDR + 0x10, 0x10, 1},       {SDRAM_TEST_ADDR + 0x11, 0x11, 1},
        {SDRAM_TEST_ADDR + 0x12, 0x12, 1},       {SDRAM_TEST_ADDR + 0x13, 0x13, 1},
        {SDRAM_TEST_ADDR + 0x20, 0x2120, 2},     {SDRAM_TEST_ADDR + 0x21, 0x2221, 2},
        {SDRAM_TEST_ADDR + 0x22, 0x2322, 2},     {SDRAM_TEST_ADDR + 0x23, 0x2423, 2},
        {SDRAM_TEST_ADDR + 0x40, 0x43424140, 4}, {SDRAM_TEST_ADDR + 0x41, 0x44434241, 4},
        {SDRAM_TEST_ADDR + 0x42, 0x45444342, 4}, {SDRAM_TEST_ADDR + 0x43, 0x46454443, 4},
        {SDRAM_TEST_ADDR + 0xa0, 0xa3a2a1a0, 4}, {SDRAM_TEST_ADDR + 0xa4, 0xa7a6a5a4, 4},
        {SDRAM_TEST_ADDR + 0xa8, 0xabaaa9a8, 4}, {SDRAM_TEST_ADDR + 0xac, 0xafaeadac, 4},
        {SDRAM_TEST_ADDR + 0xb0, 0xb3b2b1b0, 4}, {SDRAM_TEST_ADDR + 0xb4, 0xb7b6b5b4, 4},
        {SDRAM_TEST_ADDR + 0xb8, 0xbbbab9b8, 4}, {SDRAM_TEST_ADDR + 0xbc, 0xbfbebdbc, 4},
    };
    printf("sdram unalign access with dcache ... ");
    UPDATE_INFOS(winfos);
    CHECK_INFOS(rinfos);
    printf("done.\n");
    printf("current addr: %#x\n", addr);

    printf("sdram unalign access with dcache, update sdram ... ");
    outl(SDRAM_TEST_ADDR + 0xad, 0xc0cfcecd);
    case_info_t rinfos1[] = {
        {SDRAM_TEST_ADDR + 0x10, 0x10, 1},       {SDRAM_TEST_ADDR + 0x11, 0x11, 1},
        {SDRAM_TEST_ADDR + 0x12, 0x12, 1},       {SDRAM_TEST_ADDR + 0x13, 0x13, 1},
        {SDRAM_TEST_ADDR + 0x20, 0x2120, 2},     {SDRAM_TEST_ADDR + 0x21, 0x2221, 2},
        {SDRAM_TEST_ADDR + 0x22, 0x2322, 2},     {SDRAM_TEST_ADDR + 0x23, 0x2423, 2},
        {SDRAM_TEST_ADDR + 0x40, 0x43424140, 4}, {SDRAM_TEST_ADDR + 0x41, 0x44434241, 4},
        {SDRAM_TEST_ADDR + 0x42, 0x45444342, 4}, {SDRAM_TEST_ADDR + 0x43, 0x46454443, 4},
        {SDRAM_TEST_ADDR + 0xa0, 0xa3a2a1a0, 4}, {SDRAM_TEST_ADDR + 0xa4, 0xa7a6a5a4, 4},
        {SDRAM_TEST_ADDR + 0xa8, 0xabaaa9a8, 4}, {SDRAM_TEST_ADDR + 0xac, 0xcfcecdac, 4},
        {SDRAM_TEST_ADDR + 0xb0, 0xb3b2b1c0, 4}, {SDRAM_TEST_ADDR + 0xb4, 0xb7b6b5b4, 4},
        {SDRAM_TEST_ADDR + 0xb8, 0xbbbab9b8, 4}, {SDRAM_TEST_ADDR + 0xbc, 0xbfbebdbc, 4},
    };
    CHECK_INFOS(rinfos1);
    printf("done.\n");
    printf("current addr: %#x\n", addr);

    return 0;
}
