#ifndef __FLOG_H__
#define __FLOG_H__

#include <time.h>
#include <stdio.h>
#include <stdarg.h>

#define LOCALTIME(t, tm) localtime_r((t), (tm))

static void flog_print_time_stamp(FILE *pd) {
	struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
	long milliseconds = ts.tv_nsec / 1000000; // 获取毫秒部分

	time_t now = time(NULL);
    struct tm tm_now;
    LOCALTIME(&now, &tm_now); // 将秒数转换为本地时间

	fprintf(pd, "[%d/%02d/%02d %02d:%02d:%02d.%03ld] ",
           tm_now.tm_year + 1900, tm_now.tm_mon + 1, tm_now.tm_mday,
           tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec, milliseconds);
}

static inline void flog_printf(FILE *pd, const char* fmt, ...)
{
    if (!pd) return;

	flog_print_time_stamp(pd);

	va_list ap;
	va_start(ap, fmt);
	vfprintf(pd, fmt, ap);
	va_end(ap);
	fflush(pd);
}

#endif