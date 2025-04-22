#include <stdint.h>
#include "file/bin_header.h"

DECLARE_BIN_HEADER(bin_header);

static inline void outb(uintptr_t addr, uint8_t  data) { *(volatile uint8_t  *)addr = data; }
static inline void outw(uintptr_t addr, uint16_t data) { *(volatile uint16_t *)addr = data; }
static inline void outl(uintptr_t addr, uint32_t data) { *(volatile uint32_t *)addr = data; }
static inline void outll(uintptr_t addr, uint64_t data) { *(volatile uint64_t *)addr = data; }

static inline void ebreak(uint32_t arg0)
{
    /* 判断是否arg0为常数，需要开优化后才能使用 */
    if (__builtin_constant_p(arg0))
        asm volatile(
            "li a0, %0;"
            "ebreak;"
            :
            : "i"(arg0)
        );
    else
        asm volatile(
            "mv a0, %0;"
            "ebreak;"
            :
            : "r"(arg0)
        );

    // : "i"(arg0), "i"(arg1));
}

void putch(char ch)
{
    outb(0xa00003f8, ch);
}

void putstr(const char *str)
{
    if (!str) return;
    while(*str) {
        putch(*str);
        ++str;
    }
}

volatile int cnt = 0x76543210;
volatile uint64_t *rtc_addr = (volatile uint64_t *)0xa0000048;

#define UART16550_BASE      0x10000000
#define UART16550_TX        0x0

void init()
{
    for (int i=0; i<10; ++i) {
        // asm volatile(
        //     "addi a0, x0, 0x50;"
        //     "addi a1, x0, 0x51;"
        //     "addi a3, x0, 0x52;"
        //     "addi a4, x0, 0x53;"
        // );
        asm volatile(
            "mv t0, %0;"
            :
            : "r" (cnt)
            :
        );
        cnt += i;
    }

    // putstr("This is single test\n");

    // *rtc_addr;

    // *(volatile char *)(UART16550_BASE + UART16550_TX) = 'A';
    // *(volatile char *)(UART16550_BASE + UART16550_TX) = '\n';

    ebreak(0);
}
