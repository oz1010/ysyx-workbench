/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <common.h>
#include MUXDEF(CONFIG_TIMER_GETTIMEOFDAY, <sys/time.h>, <time.h>)

IFDEF(CONFIG_TIMER_CLOCK_GETTIME,
    static_assert(CLOCKS_PER_SEC == 1000000, "CLOCKS_PER_SEC != 1000000"));
IFDEF(CONFIG_TIMER_CLOCK_GETTIME,
    static_assert(sizeof(clock_t) == 8, "sizeof(clock_t) != 8"));

static uint64_t boot_time = 0;

static uint64_t get_time_internal() {
#if defined(CONFIG_TARGET_AM)
  uint64_t us = io_read(AM_TIMER_UPTIME).us;
#elif defined(CONFIG_TIMER_GETTIMEOFDAY)
  struct timeval now;
  gettimeofday(&now, NULL);
  uint64_t us = now.tv_sec * 1000000 + now.tv_usec;
#else
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC_COARSE, &now);
  uint64_t us = now.tv_sec * 1000000 + now.tv_nsec / 1000;
#endif
  return us;
}

uint64_t get_time() {
  if (boot_time == 0) boot_time = get_time_internal();
  uint64_t now = get_time_internal();
  return now - boot_time;
}

void get_hw_time_info(hw_time_info_t *info) {
#if defined(CONFIG_TARGET_AM)
  AM_TIMER_RTC_T rtc = io_read(AM_TIMER_RTC);
  info->year = rtc.year + 1900;
  info->month = rtc.month + 1;
  info->day = rtc.day;
  info->hour = rtc.hour;
  info->minute = rtc.minute;
  info->second = rtc.second;
#elif defined(CONFIG_TIMER_GETTIMEOFDAY)
  struct timeval now;
  gettimeofday(&now, NULL);
  struct tm* local_time = localtime(&now.tv_sec);
  info->year = local_time->tm_year + 1900;
  info->month = local_time->tm_mon + 1;
  info->day = local_time->tm_mday;
  info->hour = local_time->tm_hour;
  info->minute = local_time->tm_min;
  info->second = local_time->tm_sec;
#else
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC_COARSE, &now);
  struct tm* local_time = localtime(&now.tv_sec);
  info->year = local_time->tm_year + 1900;
  info->month = local_time->tm_mon + 1;
  info->day = local_time->tm_mday;
  info->hour = local_time->tm_hour;
  info->minute = local_time->tm_min;
  info->second = local_time->tm_sec;
#endif
}

void init_rand() {
  srand(get_time_internal());
}
