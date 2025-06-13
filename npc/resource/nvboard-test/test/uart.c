#include "nvboard_test.h"

int test_uart(void *arg)
{
    printf("Start test nvboard uart.\n");

    uint64_t time_s = 0;
    while(1) {
        time_s = (io_read(AM_TIMER_UPTIME).us / 1000000);
        printf("Current time(s): %u\n", time_s);
        sleep_ms(1000);
    }

    return 0;
}
