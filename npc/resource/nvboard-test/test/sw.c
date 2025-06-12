#include "nvboard_test.h"

int test_sw(void *arg)
{
    // sw读取开关值
    //   当为0x5a时退出程序
    //   否则打印当前值和期待值
    uint32_t sw_value = 0;
    uint32_t last_value = 0;
    do
    {
        sw_value = inl(GPIO_SW);
        if (sw_value == 0x5a)
        {
            printf("Get right code %#x, exit now.\n", sw_value);
            break;
        }
        if (sw_value != last_value)
        {
            printf("Get error code %#x expect %#x.\n", sw_value, 0x5a);
        }
        sleep_ms(10);
    } while (1);

    return 0;
}
