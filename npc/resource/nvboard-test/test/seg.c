#include "nvboard_test.h"

uint32_t marchid_to_seg(uint32_t marchid)
{
    uint32_t ret = 0;
    uint32_t dec_val = 10000000;

    while (dec_val > 0)
    {
        ret = (ret << 4) + marchid / dec_val;
        marchid %= dec_val;
        dec_val /= 10;
    }

    return ret;
}

int test_seg(void *arg)
{
    uint32_t value = GET_MACHINE_CSR(marchid);
    printf("marchid(dec): %d\n", value);

    uint32_t hex_value = marchid_to_seg(value);
    printf("marchid(hex): %#x\n", hex_value);
    outl(GPIO_SEG, hex_value);
    sleep_ms(5000);
    return 0;
}
