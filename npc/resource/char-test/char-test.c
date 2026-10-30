#include <stdint.h>

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

#define UART16550_BASE      0x10000000
#define UART16550_TX        (UART16550_BASE+0x0)

void _start()
{
    *(volatile char *)(UART16550_TX) = 'A';
    *(volatile char *)(UART16550_TX) = '\n';
    // while (1);
    ebreak(0);
}
