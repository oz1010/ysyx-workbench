#include <am.h>
#include <npc.h>

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

static AM_TIMER_RTC_T sys_rtc = {
    .second = 0,
    .minute = 0,
    .hour = 0,
    .day = 0,
    .month = 0,
    .year = 1900,
};

static uint64_t inline __am_get_hw_us(void)
{
    // uint64_t low = inl(RTC_ADDR);
    // uint64_t high = inl(RTC_ADDR+4);
    return *(volatile uint64_t *)RTC_ADDR;
}

static void inline __am_update_hw_time_info(void)
{
    hw_time_info_t info = *(volatile hw_time_info_t *)(RTC_ADDR+8);
    sys_rtc.year = info.year;
    sys_rtc.month = info.month;
    sys_rtc.day = info.day;
    sys_rtc.hour = info.hour;
    sys_rtc.minute = info.minute;
    sys_rtc.second = info.second;
}

void __am_timer_init()
{
    __am_update_hw_time_info();
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime)
{
    uptime->us = __am_get_hw_us();
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc)
{
    __am_update_hw_time_info();
    *rtc = sys_rtc;
}
