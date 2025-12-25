/*
 * debug.h - Debug output utilities for freestanding code
 *
 * Only used by loader.c and stub.c.
 */

#pragma once

#include "arch.h"
#include "freestanding.h"

static inline void print(const char *msg) { sys_write(2, msg, my_strlen(msg)); }

__attribute__((noreturn)) static inline void die(const char *msg) {
  print("wrapBuddy: ");
  print(msg);
  print("\n");
  sys_exit(127);
  __builtin_unreachable();
}

static inline void print_hex(uintptr_t val) {
  enum { HEX_DIGITS = sizeof(uintptr_t) * 2, BUF_SIZE = 2 + HEX_DIGITS + 1 };
  char buf[BUF_SIZE];
  buf[0] = '0';
  buf[1] = 'x';
  for (int idx = HEX_DIGITS + 1; idx >= 2; idx--) {
    int digit = val & 0xf;
    buf[idx] = digit < 10 ? '0' + digit : 'a' + digit - 10;
    val >>= 4;
  }
  buf[HEX_DIGITS + 2] = '\0';
  print(buf);
}
