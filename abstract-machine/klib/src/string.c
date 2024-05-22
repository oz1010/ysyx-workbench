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
  char *ret = dst;

  while(*src)
  {
    *dst = *src;
    ++dst;
    ++src;
  }
  dst = '\0';

  return ret;
}

char *strncpy(char *dst, const char *src, size_t n) {
  panic("Not implemented");
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
  while(*s1 && *s2 && *s1 == *s2)
  {
    ++s1;
    ++s2;
  }

  return *s1 - *s2;
}

int strncmp(const char *s1, const char *s2, size_t n) {
  panic("Not implemented");
}

void *memset(void *s, int c, size_t n) {
  int i;
  char* dst = s;

  for (i=0; i<n; ++i)
    dst[i] = c;

  return s;
}

void *memmove(void *dst, const void *src, size_t n) {
  panic("Not implemented");
}

void *memcpy(void *out, const void *in, size_t n) {
  panic("Not implemented");
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
