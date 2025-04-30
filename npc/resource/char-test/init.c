#include <stdint.h>
#include "file/bin_header.h"

DECLARE_BIN_HEADER(bin_header);

#define UART16550_BASE      0x10000000
#define UART16550_TX        (UART16550_BASE+0x0)

void _start()
{
    *(volatile char *)(UART16550_TX) = 'A';
    *(volatile char *)(UART16550_TX) = '\n';
    while (1);
}
