#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

/**
 * ref. vsrc/ysyxSoC/perip/uart16550/doc/UART_spec.pdf
*/

static uint8_t *uart_base = NULL;
static const uint32_t uart_size = 4 * 1024;

void init_uart16550()
{
    uart_base = new_vmem(uart_size);
    add_vdev_item(VDEV_INNER, "uart16550", CONFIG_UART_BASE_ADDR, uart_base, uart_size, (VDEV_ATTR_READ|VDEV_ATTR_WRITE), NULL);
}
