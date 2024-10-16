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

#ifndef __UTILS_H__
#define __UTILS_H__

#include <time.h>
#include <stdbool.h>
#include "common.h"

#define ENABLE_LOG_TIME_STAMP     true
#define LOG_TIME_STAMP_STR_MAX    48

#if ENABLE_LOG_TIME_STAMP

#ifdef WIN32 /* windows bindings */
#include <windows.h>
#define LOCALTIME(t, tm) localtime_s((tm), (t))
static inline const char *get_time_stamp_str(void) {
  static char time_stamp_str[LOG_TIME_STAMP_STR_MAX];

  SYSTEMTIME utcSystemTime;
  SYSTEMTIME st;
  TIME_ZONE_INFORMATION timeZoneInfo;

  // Get current system time (UTC)
  GetSystemTime(&utcSystemTime);

  // Set Beijing time zone information (UTC+8)
  memset(&timeZoneInfo, 0, sizeof(timeZoneInfo));
  timeZoneInfo.Bias = -480; // Beijing is UTC+8, so the bias is -8*60 minutes
  wcscpy(timeZoneInfo.StandardName, L"China Standard Time");

  // Convert UTC time to Beijing local time
  SystemTimeToTzSpecificLocalTime(&timeZoneInfo, &utcSystemTime, &st);

  // Format the timestamp
  snprintf(time_stamp_str, sizeof(time_stamp_str), "%d/%02d/%02d %02d:%02d:%02d.%03d ",
           st.wYear, st.wMonth, st.wDay,
           st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
  
  return time_stamp_str;
}

#else

#define LOCALTIME(t, tm) localtime_r((t), (tm))
static inline const char* get_time_stamp_str(void)
{
  static char time_stamp_str[LOG_TIME_STAMP_STR_MAX];

	struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
	int milliseconds = (int)(ts.tv_nsec / 1000000); // 获取毫秒部分

	time_t now = time(NULL);
  struct tm tm_now;
  LOCALTIME(&now, &tm_now); // 将秒数转换为本地时间

	snprintf(time_stamp_str, sizeof(time_stamp_str), "%d/%02d/%02d %02d:%02d:%02d.%03d",
           tm_now.tm_year + 1900, tm_now.tm_mon + 1, tm_now.tm_mday,
           tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec, milliseconds);
    
  return time_stamp_str;
}
#endif

#else

static inline const char* get_time_stamp_str(void)
{
  return "";
}

#endif

// ----------- state -----------

enum { NEMU_RUNNING, NEMU_STOP, NEMU_END, NEMU_ABORT, NEMU_QUIT };

typedef struct {
  int state;
  vaddr_t halt_pc;
  uint32_t halt_ret;
} NEMUState;

extern NEMUState nemu_state;

// ----------- timer -----------

uint64_t get_time();

// ----------- log -----------

#define ANSI_FG_BLACK   "\33[1;30m"
#define ANSI_FG_RED     "\33[1;31m"
#define ANSI_FG_GREEN   "\33[1;32m"
#define ANSI_FG_YELLOW  "\33[1;33m"
#define ANSI_FG_BLUE    "\33[1;34m"
#define ANSI_FG_MAGENTA "\33[1;35m"
#define ANSI_FG_CYAN    "\33[1;36m"
#define ANSI_FG_WHITE   "\33[1;37m"
#define ANSI_BG_BLACK   "\33[1;40m"
#define ANSI_BG_RED     "\33[1;41m"
#define ANSI_BG_GREEN   "\33[1;42m"
#define ANSI_BG_YELLOW  "\33[1;43m"
#define ANSI_BG_BLUE    "\33[1;44m"
#define ANSI_BG_MAGENTA "\33[1;35m"
#define ANSI_BG_CYAN    "\33[1;46m"
#define ANSI_BG_WHITE   "\33[1;47m"
#define ANSI_NONE       "\33[0m"

#define ANSI_FMT(str, fmt) fmt str ANSI_NONE
/*
#define _log_raw(...) IFDEF(CONFIG_TARGET_NATIVE_ELF,   \
  do {                                                  \
    extern FILE* log_fp;                                \
    extern bool log_enable();                           \
    if (log_enable()) {                                 \
      fprintf(log_fp, __VA_ARGS__);                     \
      fflush(log_fp);                                   \
    }                                                   \
    fprintf(stdout, __VA_ARGS__);                       \
    fflush(stdout);                                     \
  } while (0)                                           \
)
*/
#define _log_raw(...)                                   \
  do {                                                  \
    extern bool log_enable();                           \
    extern FILE* log_fp;                                \
    if (log_fp && (log_fp!=stdout)) {                   \
      fprintf(log_fp, __VA_ARGS__);                     \
      fflush(log_fp);                                   \
    }                                                   \
    fprintf(stdout, __VA_ARGS__);                       \
    fflush(stdout);                                     \
  } while (0)

#define _log_with_timestamp(fmt, ...)                   \
do {                                                    \
  const char *str = get_time_stamp_str();               \
  _log_raw("%s " fmt, str,  ##__VA_ARGS__);             \
} while (0)

#endif
