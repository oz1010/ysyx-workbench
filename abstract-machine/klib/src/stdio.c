#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>

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

void int_to_string(int num, char *str)
{
  int i=0;
  bool is_negative = false;

  if (num < 0)
  {
    is_negative = true;
    num = -num;
  }

  do {
    str[i++] = (num % 10) + '0';
    num /= 10;
  } while (num != 0);

  if (is_negative)
    str[i++] = '-';

  str[i] = '\0';

  reverse(str, i);
}

int printf(const char *fmt, ...) {
  panic("Not implemented");
}

int vsprintf(char *out, const char *fmt, va_list ap) {
  panic("Not implemented");
}

int sprintf(char *out, const char *fmt, ...) {
  int ret = -1;

  va_list ap;
  va_start(ap, fmt);

  ret = 0;
  while(*fmt != '\0')
  {
    char c = *fmt++;
    switch (c)
    {
    case '%':
      switch (*fmt++)
      {
      case 's':
      {
        char* str = va_arg(ap, char*);
        size_t len = strlen(str);
        memcpy(out, str, len);
        out += len;
        ret += len;
        break;
      }

      case 'd':
      {
        char str[32] = {0};
        int num = va_arg(ap, int);
        int_to_string(num, str);
        size_t len = strlen(str);
        memcpy(out, str, len);
        out += len;
        ret += len;
        break;
      }

      case '%':
        *out++ = '%';
        ++ret;
        break;
      
      default:
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

  va_end(ap);

  *out = '\0';

  return ret;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
  panic("Not implemented");
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  panic("Not implemented");
}

#endif
