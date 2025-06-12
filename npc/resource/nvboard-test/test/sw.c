#include "nvboard_test.h"

#define SW_EXPECT_VALUE 0xe4

int test_sw(void *arg)
{
    // sw读取开关值
    //   当为SW_EXPECT_VALUE时退出程序
    //   否则打印当前值和期待值
    uint32_t sw_value = 0;
    uint32_t last_value = 0;
    do
    {
        sw_value = inl(GPIO_SW);
        if (sw_value == SW_EXPECT_VALUE)
        {
            printf("Get right code %#x, exit now.\n", sw_value);
            break;
        }
        if (sw_value != last_value)
        {
            last_value = sw_value;
            printf("Get error code %#x expect %#04x.\n", sw_value, SW_EXPECT_VALUE);
        }
        sleep_ms(10);
    } while (1);

    return 0;
}
