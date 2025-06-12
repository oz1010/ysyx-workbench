#ifndef __NVBOARD_TEST__
#define __NVBOARD_TEST__

#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"
#include "generated/autoconf.h"

#define GPIO_LED    (CONFIG_GPIO_BASE_ADDR + 0x0)
#define GPIO_SW     (CONFIG_GPIO_BASE_ADDR + 0x4)
#define GPIO_SEG    (CONFIG_GPIO_BASE_ADDR + 0x8)

typedef struct 
{
    const char* cmd;
    int (*handler)(void *);
} test_case_t;

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

static inline void sleep_ms(uint64_t ms)
{
    uint64_t next_ms = (io_read(AM_TIMER_UPTIME).us / 1000) + ms;
    while (io_read(AM_TIMER_UPTIME).us / 1000 < next_ms);
}

#endif
