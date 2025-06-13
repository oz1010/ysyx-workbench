#include "nvboard_test.h"

int test_uart(void *arg)
{
    printf("Start test nvboard uart, input 'q' or 'Q' to exit.\n");

    char input_char = 0;
    while (1)
    {
        int input = getch();
        if (input > 0)
        {
            input_char = input & 0xff;
            printf("input: '%c'(%#x)\n", input_char, input_char);

            if (input_char == 'q' || input_char == 'Q')
            {
                break;
            }
        }
    }

    return 0;
}
