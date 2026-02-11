#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

/**
 * ref. vsrc/ysyxSoC/perip/uart16550/doc/UART_spec.pdf
 */

static uint8_t *uart_base = NULL;
static const uint32_t uart_size = 4 * 1024;
static uint8_t uart_lcr_mode = 0; /* 用于切换配置模式 */

#define SERIAL_PORT CONFIG_UART_BASE_ADDR
#define UART16550_REG_LCR (SERIAL_PORT + 0x3)
#define UART16550_REG_LSR (SERIAL_PORT + 0x5)
#define UART16550_REG_DL0 (SERIAL_PORT + 0x0)
#define UART16550_REG_DL1 (SERIAL_PORT + 0x1)
#define bits(n) (0x1 << (n))

void uart16550_handler(void *item_arg, bool is_write, vaddr_t addr, int len, word_t *data)
{
#if CONFIG_ISA_RISCV_SINGLE
    vdev_item_t *vdev = (vdev_item_t *)item_arg;
    assert(vdev);

    if (len == 1)
    {
        if (is_write)
        {
            switch (addr)
            {
                // case UART16550_REG_DL0:
                case SERIAL_PORT:
                    if (!uart_lcr_mode)
                    {
                        printf("%c", *data & 0xff);
                    }
                    else
                    {
                    }
                    break;
                case UART16550_REG_LCR:
                    uart_lcr_mode = *data & 0xff;
                    break;

                case UART16550_REG_DL1:
                    break;

                default:
                    printf("access uart16550 error, %s %#.8x %d \n", (is_write ? "write" : "read"),
                           addr, len);
                    assert(0 && "don't support access uart16550");
                    break;
            }
        }
        else
        {
            switch (addr)
            {
                case UART16550_REG_LSR:
                    *data = bits(6);
                    break;
                case UART16550_REG_LCR:
                    *data = 0;
                    break;

                default:
                    printf("access uart16550 error, %s %#.8x %d \n", (is_write ? "write" : "read"),
                           addr, len);
                    assert(0 && "don't support access uart16550");
                    break;
            }
        }
    }
#endif
}

void init_uart16550()
{
    (void)uart_lcr_mode;
    uart_base = new_vmem(uart_size);
    add_vdev_item(VDEV_INNER, "uart16550", CONFIG_UART_BASE_ADDR, uart_base, uart_size,
                  (VDEV_ATTR_READ | VDEV_ATTR_WRITE), uart16550_handler);
}
