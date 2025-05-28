#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

__attribute__((noinline))
void check(bool cond) {
  if (!cond) halt(1);
}

static inline uint8_t  inb(uintptr_t addr) { return *(volatile uint8_t  *)addr; }
static inline uint16_t inw(uintptr_t addr) { return *(volatile uint16_t *)addr; }
static inline uint32_t inl(uintptr_t addr) { return *(volatile uint32_t *)addr; }
static inline uint64_t inll(uintptr_t addr) { return *(volatile uint64_t *)addr; }
static inline void outb(uintptr_t addr, uint8_t data) { *(volatile uint8_t *)addr = data; }
static inline void outw(uintptr_t addr, uint16_t data) { *(volatile uint16_t *)addr = data; }
static inline void outl(uintptr_t addr, uint32_t data) { *(volatile uint32_t *)addr = data; }

#define CHECK_DATA(type, a, b) do{ type a_v=(a); type b_v=(b); if(a_v!=b_v) halt((int)b_v);}while(0)

#define PSRAM_ADDR          0x80000000
#define PSRAM_SIZE          0x00400000

#define PSRAM_ADDR_START1   0x80000000
#define PSRAM_SIZE1         0x00000400
#define PSRAM_ADDR_END1 (PSRAM_ADDR_START1+PSRAM_SIZE1)

#define PSRAM_ADDR_START2 PSRAM_ADDR_END1
#define PSRAM_SIZE2         0x00000400
#define PSRAM_ADDR_END2 (PSRAM_ADDR_START2+PSRAM_SIZE2)

#define PSRAM_ADDR_START3 PSRAM_ADDR_END2
#define PSRAM_SIZE3         0x00000400
#define PSRAM_ADDR_END3 (PSRAM_ADDR_START3+PSRAM_SIZE3)

#if (PSRAM_ADDR_END3>(PSRAM_ADDR+PSRAM_SIZE))
#pragma message "PSRAM_ADDR_END3=" TOSTRING(PSRAM_ADDR_END3) ", PSRAM_ADDR+PSRAM_SIZE=" TOSTRING((PSRAM_ADDR + PSRAM_SIZE))
#error "PSRAM test is out of range. "
#endif

int main() {
    uint32_t addr;

    for (uint32_t offset=0; offset<1; ++offset) {
        for (addr=PSRAM_ADDR_START1+offset; addr<PSRAM_ADDR_END1; addr+=1) 
            outb(addr, addr);
        for (addr=PSRAM_ADDR_START1+offset; addr<PSRAM_ADDR_END1; addr+=1) 
            CHECK_DATA(uint8_t, inb(addr), addr);
    }
    
    for (uint32_t offset=0; offset<2; ++offset) {
        for (addr=PSRAM_ADDR_START2+offset; addr<PSRAM_ADDR_END2; addr+=2) 
            outw(addr, addr);
        for (addr=PSRAM_ADDR_START2+offset; addr<PSRAM_ADDR_END2; addr+=2) 
            CHECK_DATA(uint16_t, inw(addr), addr);
    }

    for (uint32_t offset=0; offset<4; ++offset) {
        for (addr=PSRAM_ADDR_START3+offset; addr<PSRAM_ADDR_END3; addr+=4) 
            outl(addr, addr);
        for (addr=PSRAM_ADDR_START3+offset; addr<PSRAM_ADDR_END3; addr+=4) 
            CHECK_DATA(uint32_t, inl(addr), addr);
    }

    return 0;
}
