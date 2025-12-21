/*
 * common.h - Common utilities for wrapBuddy stub and loader
 *
 * Includes architecture-specific code and provides portable utilities.
 */

#pragma once

#include "arch.h"
#include "types.h"

/*
 * String functions
 */

static inline size_t my_strlen(const char *s) {
  const char *p = s;
  while (*p)
    p++;
  return p - s;
}

static inline void my_memcpy(void *dst, const void *src, size_t n) {
  char *d = dst;
  const char *s = src;
  while (n--)
    *d++ = *s++;
}

static inline void my_memset(void *dst, int c, size_t n) {
  char *d = dst;
  while (n--)
    *d++ = c;
}

/*
 * Debug output
 */

static inline void print(const char *msg) { sys_write(2, msg, my_strlen(msg)); }

__attribute__((noreturn)) static inline void die(const char *msg) {
  print("wrapBuddy: ");
  print(msg);
  print("\n");
  sys_exit(127);
  __builtin_unreachable();
}

static inline void print_hex(uint64_t val) {
  char buf[19];
  buf[0] = '0';
  buf[1] = 'x';
  for (int i = 17; i >= 2; i--) {
    int d = val & 0xf;
    buf[i] = d < 10 ? '0' + d : 'a' + d - 10;
    val >>= 4;
  }
  buf[18] = '\0';
  print(buf);
}

