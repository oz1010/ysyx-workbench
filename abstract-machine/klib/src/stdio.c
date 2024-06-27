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
  static char buf[1024];
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

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  size_t ret = 0;
  size_t max_size = n > 0 ? n - 1 : 0;

  while(*fmt != '\0' && ret < max_size)
  {
    char c = *fmt++;
    switch (c)
    {
    case '%':
      char select_c = *fmt++;
      switch (select_c)
      {
      case 's':
      {
        char* str = va_arg(ap, char*);
        size_t len = strlen(str);
        len = len > (max_size - ret) ? (max_size - ret) : len;
        memcpy(out, str, len);
        out += len;
        ret += len;
        break;
      }

      case 'd':
      {
        char str[32] = {0};
        int num = va_arg(ap, int);
        size_t len = int_to_string(num, 10, str);
        len = len > (max_size - ret) ? (max_size - ret) : len;
        memcpy(out, str, len);
        out += len;
        ret += len;
        break;
      }
      
      case 'x':
      {
        char str[32] = {0};
        uint32_t num = (uint32_t)va_arg(ap, int);
        size_t len = uint32_to_string(num, 16, str);
        len = len > (max_size - ret) ? (max_size - ret) : len;
        memcpy(out, str, len);
        out += len;
        ret += len;
        break;
      }

      case 'c':
      {
        char input_c = (char)va_arg(ap, int);
        *out++ = input_c;
        ++ret;
        break;
      }

      case '%':
        *out++ = '%';
        ++ret;
        break;
      
      default:
        putstr("Found unsupported char '");
        putch(select_c);
        putstr("'\n");
        panic("Not implemented");
        break;
      }
      break;

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
