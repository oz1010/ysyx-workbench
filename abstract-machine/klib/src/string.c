#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

size_t strlen(const char *s) {
  size_t len = 0;

  while(*s) {
    ++len;
    ++s;
  }

  return len;
}

char *strcpy(char *dst, const char *src) {
  return strncpy(dst, src, SIZE_MAX);
}

char *strncpy(char *dst, const char *src, size_t n) {
  char *ret = dst;

  while(*src && n-->0)
  {
    *dst = *src;
    ++dst;
    ++src;
  }
  dst = '\0';

  return ret;
}

char *strcat(char *dst, const char *src) {
  size_t dst_len = strlen(dst);
  char *ret = dst;

  while(*src){
    dst[dst_len] = *src;
    ++dst;
    ++src;
  }
  dst[dst_len] = '\0';

  return ret;
}

int strcmp(const char *s1, const char *s2) {
  return strncmp(s1, s2, SIZE_MAX);
}

int strncmp(const char *s1, const char *s2, size_t n) {
  while(*s1 && *s2 && *s1 == *s2 && n-->0)
  {
    ++s1;
    ++s2;
  }

  return *s1 - *s2;
}

void *memset(void *s, int c, size_t n) {
  int i;
  unsigned char* dst = s;

  for (i=0; i<n; ++i)
    dst[i] = c;

  return s;
}

void *memmove(void *dst, const void *src, size_t n) {
  int i;
  unsigned char* d = dst;
  const unsigned char* s = src;

  for (i=0; i<n; ++i)
    d[i] = s[i];

  return dst;
}

void *memcpy(void *out, const void *in, size_t n) {
  const unsigned char *n1 = in;
  unsigned char *n2 = out;
  int i;

  for (i=0; i<n; ++i)
    *n2++ = *n1++;

  return out;
}

int memcmp(const void *s1, const void *s2, size_t n) {
  const unsigned char *n1 = s1;
  const unsigned char *n2 = s2;
  int i;

  for (i=0; i<n; ++i) {
    if (n1[i] != n2[i]) {
      break;
    }
  }

  if (i==n)
    return 0;
  else
    return n1[i] - n2[i];
}

#endif
