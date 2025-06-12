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

#define GPIO_ADDR 0x10002000
#define GPIO_LED (GPIO_ADDR + 0x0)

void sleep_ms(uint64_t ms)
{
    uint64_t next_ms = (io_read(AM_TIMER_UPTIME).us / 1000) + ms;
    while (io_read(AM_TIMER_UPTIME).us / 1000 < next_ms);
}

int main()
{
    // led流水灯效果
    for (size_t cnt = 0; cnt < 1; cnt++)
    {
        outl(GPIO_LED, 0);
        uint32_t value = 0x05;
        for (size_t i = 0; i < 16; i++)
        {
            outl(GPIO_LED, value << i);
            sleep_ms(500);
        }
    }

    return 0;
}
