#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

static inline uint8_t  inb(uintptr_t addr) { return *(volatile uint8_t  *)addr; }
static inline uint16_t inw(uintptr_t addr) { return *(volatile uint16_t *)addr; }
static inline uint32_t inl(uintptr_t addr) { return *(volatile uint32_t *)addr; }
static inline uint64_t inll(uintptr_t addr) { return *(volatile uint64_t *)addr; }
static inline void outb(uintptr_t addr, uint8_t data) { *(volatile uint8_t *)addr = data; }
static inline void outw(uintptr_t addr, uint16_t data) { *(volatile uint16_t *)addr = data; }
static inline void outl(uintptr_t addr, uint32_t data) { *(volatile uint32_t *)addr = data; }

#define CHECK_DATA(type, a, b) do{ type a_v=(a); type b_v=(b); if(a_v!=b_v) halt((int)b_v);}while(0)

#define SDRAM_ADDR          0xa0000000
#define SDRAM_SIZE          0x20000000
#define SDRAM_END           (SDRAM_ADDR+SDRAM_SIZE)
#define SDRAM_MIX_SIZE      (SDRAM_SIZE >> 0)   // 全域混合测试
#define SDRAM_MIX_STEP      0x01000000          // 全域混合测试，单步跳转

#define SDRAM_TEST_ADDR     SDRAM_ADDR
#define SDRAM_TEST_SIZE     0x00000010
#define SDRAM_TEST_END      (SDRAM_TEST_ADDR+SDRAM_TEST_SIZE)

int main() {
    uint32_t addr;

    addr = SDRAM_TEST_ADDR + 0x98;
    outl(addr, 0x33323130);
    printf("read %x %x\n", addr, inl(addr));
    CHECK_DATA(uint32_t, inl(addr), 0x33323130);

    // /* 非字节对齐访问检测 */
    // for (uint32_t offset=0; offset<1; ++offset) {
    //     for (addr=SDRAM_TEST_ADDR+offset; addr<SDRAM_TEST_END; addr+=1) 
    //         outb(addr, addr);
    //     for (addr=SDRAM_TEST_ADDR+offset; addr<SDRAM_TEST_END; addr+=1) 
    //         CHECK_DATA(uint8_t, inb(addr), addr);
    // }
    
    // for (uint32_t offset=0; offset<2; ++offset) {
    //     for (addr=SDRAM_TEST_ADDR+offset; addr<SDRAM_TEST_END; addr+=2) 
    //         outw(addr, addr);
    //     for (addr=SDRAM_TEST_ADDR+offset; addr<SDRAM_TEST_END; addr+=2) 
    //         CHECK_DATA(uint16_t, inw(addr), addr);
    // }

    // for (uint32_t offset=0; offset<4; ++offset) {
    //     for (addr=SDRAM_TEST_ADDR+offset; addr<SDRAM_TEST_END; addr+=4) 
    //         outl(addr, addr);
    //     for (addr=SDRAM_TEST_ADDR+offset; addr<SDRAM_TEST_END; addr+=4) 
    //         CHECK_DATA(uint32_t, inl(addr), addr);
    // }

    // /* 全域混合读写访问检测 */
    // uint32_t asizes[] = {1,2,4};
    // uint32_t asize;
    // for (addr=SDRAM_ADDR; addr<(SDRAM_ADDR+SDRAM_MIX_SIZE-3);) {
    //     for (uint32_t idx=0; idx<(sizeof(asizes)/sizeof(asizes[0])); ++idx) {
    //         asize = asizes[idx];
    //         switch(asize) {
    //             case 1: outb(addr, addr); break;
    //             case 2: outw(addr, addr); break;
    //             case 4: outl(addr, addr); break;
    //             default: halt(-1);
    //         }
    //         addr += asize;
    //     }
    //     addr += SDRAM_MIX_STEP;
    // }
    // for (addr=SDRAM_ADDR; addr<(SDRAM_ADDR+SDRAM_MIX_SIZE-3);) {
    //     for (uint32_t idx=0; idx<(sizeof(asizes)/sizeof(asizes[0])); ++idx) {
    //         asize = asizes[idx];
    //         switch(asize) {
    //             case 1: CHECK_DATA(uint8_t, inb(addr), addr); break;
    //             case 2: CHECK_DATA(uint16_t, inw(addr), addr); break;
    //             case 4: CHECK_DATA(uint32_t, inl(addr), addr); break;
    //             default: halt(-1);
    //         }
    //         addr += asize;
    //     }
    //     addr += SDRAM_MIX_STEP;
    // }

    return 0;
}
