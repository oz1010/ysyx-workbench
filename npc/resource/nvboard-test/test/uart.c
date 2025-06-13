#include "nvboard_test.h"

// while((inb(UART16550_REG_LSR)&bits(6)) != bits(6))
#define SERIAL_PORT (0x10000000)
#define UART16550_REG_RX_BUF (SERIAL_PORT + 0x0)
#define UART16550_REG_TX_BUF (SERIAL_PORT + 0x0)
#define UART16550_REG_LCR (SERIAL_PORT + 0x3)
#define UART16550_REG_LSR (SERIAL_PORT + 0x5)
// value=sys_clk/(16*baud), 需要先写DL1，写DL0模块会立即开始工作
#define UART16550_REG_DL0 (SERIAL_PORT + 0x0)
#define UART16550_REG_DL1 (SERIAL_PORT + 0x1)
#define bits(n) (0x1 << (n))

int test_uart(void *arg)
{
    printf("Start test nvboard uart, input 'q' or 'Q' to exit.\n");

    char input_char = 0;
    while (1)
    {
        if ((inb(UART16550_REG_LSR) & bits(0)) == bits(0))
        {
            input_char = inb(UART16550_REG_RX_BUF);
            printf("input: '%c'(%#x)\n", input_char, input_char);

            if (input_char == 'q' || input_char == 'Q')
            {
                break;
            }
        }
    }

    return 0;
}
