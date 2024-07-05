#include <am.h>
#include <nemu.h>

static AM_TIMER_RTC_T sys_rtc = {
  .second = 0,
  .minute = 0,
  .hour   = 0,
  .day    = 0,
  .month  = 0,
  .year   = 1900,
};

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  // uint64_t low = inl(RTC_ADDR);
  // uint64_t high = inl(RTC_ADDR+4);
  uptime->us = *(volatile uint64_t*)RTC_ADDR;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  *rtc = sys_rtc;
}
