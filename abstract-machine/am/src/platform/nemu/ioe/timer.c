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
static AM_TIMER_UPTIME_T sys_uptime = { 0 };

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  // TODO 模拟时间计数
  sys_uptime.us += 50;
  *uptime = sys_uptime;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  *rtc = sys_rtc;
}
