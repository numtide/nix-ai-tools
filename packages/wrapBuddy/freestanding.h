/*
 * freestanding.h - Types and utilities for freestanding C code
 *
 * Uses compiler builtins for fixed-width types to avoid any libc headers.
 * This allows cross-compilation with just -m32 without needing 32-bit stubs.
 *
 * Only used by the loader and stub, not by the C++ patcher.
 */

#pragma once

/* Fixed-width types using compiler builtins */
typedef __INT8_TYPE__ int8_t;
typedef __INT16_TYPE__ int16_t;
typedef __INT32_TYPE__ int32_t;
typedef __INT64_TYPE__ int64_t;
typedef __UINT8_TYPE__ uint8_t;
typedef __UINT16_TYPE__ uint16_t;
typedef __UINT32_TYPE__ uint32_t;
typedef __UINT64_TYPE__ uint64_t;

/* Pointer-sized types */
typedef __UINTPTR_TYPE__ uintptr_t;
typedef __INTPTR_TYPE__ intptr_t;
typedef __SIZE_TYPE__ size_t;
typedef __INTPTR_TYPE__ ssize_t;

/* NULL pointer */
#define NULL ((void *)0)

/*
 * String functions (replacements for libc)
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
