#include "nvboard_test.h"
#include "generated/autoconf.h"

#define PS2_READ (CONFIG_PS2_BASE_ADDR + 0x0)

int test_ps2(void *arg)
{
    while (1)
    {
        uint8_t ps_code = inb(PS2_READ);
        printf("Read ps code: %x\n", ps_code);
        sleep_ms(1000);
    }

    return 0;
}
