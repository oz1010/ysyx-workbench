#include <am.h>
#include <npc.h>
#include "klib.h"
#include "generated/autoconf.h"

extern char _heap_start;
int main(const char *args);

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = MAINARGS_PLACEHOLDER; // defined in CFLAGS

void putch(char ch)
{
#if CONFIG_HAS_UART
    SERILAL_STATUE_CHECK();
    outb(SERIAL_PORT, ch);
#endif
}

int getch()
{
#if CONFIG_HAS_UART
    if ((inb(UART16550_REG_LSR) & bits(0)) == bits(0))
        return inb(SERIAL_PORT);
    return -1;
#else
    return -1;
#endif
}

void halt(int code)
{
    npc_trap(code);

    // should not reach here
    while (1)
        ;
}

void init_uart16550()
{
#if CONFIG_HAS_UART
    uint8_t val = inb(UART16550_REG_LCR);
    outb(UART16550_REG_LCR, val |= bits(7));
    // 文档中计算值为：DL = sys_clk / (16*BAUD_RATE)
    // 这个值决定UART单比特持续时间（DL*16）ticks
    // 仿真中DL值范围[1,2^16)，0为默认值会禁用整个IO，1为BAUD_RATE最大值
    outb(UART16550_REG_DL1, 0x00);
    outb(UART16550_REG_DL0, 0x01);
    outb(UART16550_REG_LCR, val &= ~bits(7));
#endif
}

void print_machine_info()
{
    union
    {
        uint32_t id;
        uint8_t str[8];
    } vendor_info;
    memset(&vendor_info, 0, sizeof(vendor_info));
    vendor_info.id=GET_MACHINE_CSR(mvendorid);
#if CONFIG_HAS_UART
    printf("Machine info: %s_%d\n", vendor_info.str, GET_MACHINE_CSR(marchid));
#endif
#if CONFIG_HAS_GPIO
    outl(CONFIG_GPIO_BASE_ADDR + 0x8, 0x23060295);
#endif
}

void _trm_init()
{
    init_uart16550();
    print_machine_info();

    int ret = main(mainargs);
    halt(ret);
}
