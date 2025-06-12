#include "nvboard_test.h"

int test_seg(void *arg)
{
    uint32_t value = GET_MACHINE_CSR(marchid);
    printf("marchid: %d\n", value);
    outl(GPIO_SEG, value);
    return 0;
}
