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

static inline size_t my_strlen(const char *str) {
  const char *ptr = str;
  while (*ptr) {
    ptr++;
  }
  return ptr - str;
}

static inline void my_memcpy(void *dst, const void *src, size_t len) {
  char *dest = dst;
  const char *source = src;
  while (len--) {
    *dest++ = *source++;
  }
}

static inline void my_memset(void *dst, int val, size_t len) {
  char *dest = dst;
  while (len--) {
    *dest++ = val;
  }
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
  for (int idx = 17; idx >= 2; idx--) {
    int digit = val & 0xf;
    buf[idx] = digit < 10 ? '0' + digit : 'a' + digit - 10;
    val >>= 4;
  }
  buf[18] = '\0';
  print(buf);
}
