#include "nvboard_test.h"

#define OUT_COLOR(num) case num: printf("\033[3" #num "minput: \033[4" #num "m'%c'(%#x)\033[0m\n", input_char, input_char); break

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
            switch(input_char-'0') {
                OUT_COLOR(0);
                OUT_COLOR(1);
                OUT_COLOR(2);
                OUT_COLOR(3);
                OUT_COLOR(4);
                OUT_COLOR(5);
                OUT_COLOR(6);
                OUT_COLOR(7);
                OUT_COLOR(8);
                default: printf("input: '%c'(%#x)\n", input_char, input_char);
            }

            if (input_char == 'q' || input_char == 'Q')
            {
                break;
            }
        }
    }

    return 0;
}
