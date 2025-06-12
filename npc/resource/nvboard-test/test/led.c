#include "nvboard_test.h"

int test_led(void *arg)
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
