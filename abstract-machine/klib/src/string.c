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

inline char *strcpy(char *dst, const char *src) {
  return strncpy(dst, src, strlen(src) + 1);
}

char *strncpy(char *dst, const char *src, size_t n) {
  size_t i;

  for (i=0; i<n&&src[i]!='\0'; ++i)
    dst[i] = src[i];
  for (; i<n; ++i)
    dst[i] = '\0';

  return dst;
}

char *strcat(char *dst, const char *src) {
  size_t dst_len = strlen(dst);
  char *ret = dst;

  while(*src){
    dst[dst_len++] = *src;
    ++src;
  }
  dst[dst_len++] = '\0';

  return ret;
}

inline int strcmp(const char *s1, const char *s2) {
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

  /* 设置4字节0 */
  size_t num_4 = n / 4;
  uint32_t *out_4 = s;
  uint32_t val_4 = c&0xFF;
  val_4 = (val_4 << 24) | (val_4 << 16) | (val_4 << 8) | (val_4 << 0);
  for (i=0; i<num_4; ++i)
    *out_4++ = val_4;

  /* 设置剩余字节 */
  size_t num_1 = n % 4;
  uint8_t *out_1 = (void *)out_4;
  for (i=0; i<num_1; ++i)
    *out_1++ = (uint8_t)c;

  return s;
}

inline void *memmove(void *dst, const void *src, size_t n) {
  return memcpy(dst, src, n);
}

void *memcpy(void *out, const void *in, size_t n) {
  int i;

  /* 拷贝4字节 */
  size_t num_4 = n / 4;
  uint32_t *out_4 = out;
  const uint32_t *in_4 = in;
  for (i=0; i<num_4; ++i)
    *out_4++ = *in_4++;

  /* 拷贝剩余字节 */
  size_t num_1 = n % 4;
  uint8_t *out_1 = (void *)out_4;
  const uint8_t *in_1 = (const void *)in_4;
  for (i=0; i<num_1; ++i)
    *out_1++ = *in_1++;

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
