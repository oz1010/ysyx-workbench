#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>
#include <stdint.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

void reverse(char* str, int length)
{
  int start = 0;
  int end = length -1;

  while(start < end) {
    char tmp = str[start];
    str[start] = str[end];
    str[end] = tmp;
    ++start;
    --end;
  }
}

// 无符号32位数字转字符串，返回值为字符串长度
size_t uint32_to_string(uint32_t num, size_t base, char *str)
{
  uint32_t left = num % base;
  size_t idx = 0;

  // 基数最大为16
  if (base > 16 || base < 2)
  {
    panic("the base of int_to_hex_string is error");
  }

  // 若数值超过基数，需要先递归
  if (num >= base)
  {
    idx = uint32_to_string((num/base), base, str);
  }
    
  // 向str输出字符
  if (left<10)
    str[idx] = left + '0';
  else
    str[idx] = left - 10 + 'a';

  str[idx+1] = '\0';
  return idx + 1;
}

// 有符号整数转字符串，返回值为字符串长度
size_t int_to_string(int num, size_t base, char *str)
{
  size_t len = 0;
  uint32_t n = num;
  
  if (num < 0)
  {
    n = -num;
    str[len] = '-';
    ++len;
    ++str;
  }

  len += uint32_to_string(n, base, str);

  return len;
}

int printf(const char *fmt, ...) {
  static char buf[102400];
  int ret = -1;

  va_list ap;
  va_start(ap, fmt);
  ret = vsnprintf(buf, sizeof(buf)/sizeof(buf[0]), fmt, ap);
  va_end(ap);

  putstr(buf);

  return ret;
}

int vsprintf(char *out, const char *fmt, va_list ap) {
  return vsnprintf(out, SIZE_MAX, fmt, ap);
}

int sprintf(char *out, const char *fmt, ...) {
  int ret = -1;

  va_list ap;
  va_start(ap, fmt);

  ret = vsprintf(out, fmt, ap);

  va_end(ap);

  return ret;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
  int ret = -1;

  va_list ap;
  va_start(ap, fmt);

  ret = vsnprintf(out, n, fmt, ap);

  va_end(ap);

  return ret;
}

// 将字符串输出到指定输出口处
inline size_t copy_to_output(char **out, const size_t ret, const int max_size, const char *str, size_t len)
{
  len = len > (max_size - ret) ? (max_size - ret) : len;
  memcpy(*out, str, len);
  *out += len;
  return len;
}

// 当字符串长度低于限长时，使用0补全
void add_zero_prefix(char *str, size_t *str_len, int limit_len)
{
  size_t len = *str_len;
  if (len < limit_len) 
  {
    size_t mv_len = limit_len - len;
    char tmp_str[32] = {0};
    memcpy(&tmp_str[mv_len], &str[0], len);
    memset(&tmp_str[0], '0', mv_len);
    len += mv_len;
    memcpy(&str[0], &tmp_str[0], len);
  }
  *str_len = len;
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  size_t ret = 0;
  size_t max_size = n > 0 ? n - 1 : 0;

  while(*fmt != '\0' && ret < max_size)
  {
    char c = *fmt++;
    switch (c)
    {
    case '%':
    {
      bool hex_prefix = false;
      bool zero_prefix = false;
      int limit_len = 0;

      // 是否hex前缀
      if (*fmt == '#') {
        ++fmt;
        hex_prefix = true;
      }

      // 是否0补位解析
      if (*fmt == '0') {
        ++fmt;
        zero_prefix = true;
      }

      // 限位数解析
      // TODO 修复无法识别限位数的bug
      const char* start_fmt = fmt;
      while(limit_len>=0 && *fmt>='0' && *fmt<='9') {
        ++fmt;
      }
      if (limit_len < 0) {
        putstr("Found too long limit \"");
        while(start_fmt<fmt) {
          putch(*start_fmt);
          ++start_fmt;
        }
        putstr("\"\n");
        panic("Not implemented");
      }

      char select_c = *fmt++;
      switch (select_c)
      {
      case 's':
      {
        char* str = va_arg(ap, char*);
        size_t len = strlen(str);
        ret += copy_to_output(&out, ret, max_size, str, len);
        break;
      }

      case 'd':
      {
        char str[32] = {0};
        int num = va_arg(ap, int);
        size_t len = int_to_string(num, 10, str);
        if (zero_prefix) add_zero_prefix(str, &len, limit_len);
        ret += copy_to_output(&out, ret, max_size, str, len);
        break;
      }
      
      case 'x':
      {
        char str[32] = {0};
        uint32_t num = (uint32_t)va_arg(ap, int);
        size_t len = uint32_to_string(num, 16, str);
        if (hex_prefix) ret += copy_to_output(&out, ret, max_size, "0x", 2);
        if (zero_prefix) add_zero_prefix(str, &len, limit_len);
        ret += copy_to_output(&out, ret, max_size, str, len);
        break;
      }

      case 'p':
      {
        ret += copy_to_output(&out, ret, max_size, "0x", 2);
        char str[32] = {0};
        uint32_t num = (uint32_t)va_arg(ap, int*);
        size_t len = uint32_to_string(num, 16, str);
        if (zero_prefix) add_zero_prefix(str, &len, limit_len);
        ret += copy_to_output(&out, ret, max_size, str, len);
        break;
      }

      case 'c':
      {
        char input_c = (char)va_arg(ap, int);
        ret += copy_to_output(&out, ret, max_size, &input_c, 1);
        break;
      }

      case '%':
        ret += copy_to_output(&out, ret, max_size, "\%", 1);
        break;
      
      default:
      {
        char str[32] = {0};
        uint32_t num = (uint32_t)select_c;
        uint32_to_string(num, 16, str);
        putstr("Found unsupported char '");
        putch(select_c);
        putstr("'(0x");
        putstr(str);
        putstr(")\n");
        panic("Not implemented");
        break;
      }
      }
      break;
    }

    case '\\':
      *out++ = *fmt++;
      ++ret;
      break;
    
    default:
      *out++ = c;
      ++ret;
      break;
    }
  }

  if (n > 0) {
    *out++ = '\0';
    ++ret;
  }

  return ret;
}

#endif
