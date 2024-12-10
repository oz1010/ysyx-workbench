#include <stdio.h>
#include "utils.h"

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
const char* get_time_stamp_str(void)
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
