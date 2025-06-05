#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

typedef union hw_time_info
{
    uint64_t time_raw_val;
    struct
    {
        uint64_t year : 12;
        uint64_t month : 4;
        uint64_t day : 5;
        uint64_t hour : 5;
        uint64_t minute : 6;
        uint64_t second : 6;
    };
} hw_time_info_t;

#define CLINT_TIME_ADDR 0x02000048
#define CLINT_HW_TIME_ADDR 0x02000050

static inline uint64_t inll(uintptr_t addr) { return *(volatile uint64_t *)addr; }

int main() {
    printf("clint-test case start\n");
    uint64_t up_time = inll(CLINT_TIME_ADDR);
    hw_time_info_t rtc;
    rtc.time_raw_val = inll(CLINT_HW_TIME_ADDR);

    printf("up time: %ld\n", up_time);
    printf("hw time: %d-%d-%d %02d:%02d:%02d GMT\n", rtc.year, rtc.month, rtc.day, rtc.hour, rtc.minute, rtc.second);

    printf("clint-test case done\n");
    return 0;
}
