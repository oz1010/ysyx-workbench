#include "nvboard_test.h"

#define ARRLEN(arr) (int)(sizeof(arr) / sizeof(arr[0]))
#define TEST_CASE(cmd) {#cmd, test_##cmd}

int test_led(void *arg);
int test_sw(void *arg);

test_case_t test_cases[] = {
    TEST_CASE(led),
    TEST_CASE(sw),
};

int main(const char *args)
{
    for (size_t i = 0; i < ARRLEN(test_cases); ++i)
    {
        test_case_t *item = &test_cases[i];
        if (0 == strcmp(args, item->cmd))
        {
            return item->handler(NULL);
        }
    }

    printf("Input error mainargs: %s\n", args);
    printf("Usage: make run mainargs=*\n");
    for (size_t i = 0; i < ARRLEN(test_cases); ++i)
    {
        test_case_t *item = &test_cases[i];
        printf("  %d. %s\n", i + 1, item->cmd);
    }

    return 0;

    return 0;
}
