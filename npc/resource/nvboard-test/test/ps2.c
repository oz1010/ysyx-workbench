#include "nvboard_test.h"
#include "generated/autoconf.h"

int test_ps2(void *arg)
{
    printf("Start test nvboard keyboard, input <Q> to exit.\n");

    while (1)
    {
        AM_INPUT_KEYBRD_T ev = io_read(AM_INPUT_KEYBRD);
        if (ev.keycode)
        {
            printf("%#x - %s\n", ev.keycode, ev.keydown?"down":"release");
            if (!ev.keydown && ev.keycode == 0x15)
            {
                break;
            }
        }
    }

    return 0;
}
