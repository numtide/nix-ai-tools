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

/* Check if syscall result is an error (kernel returns -1 to -4095 for errors)
 * This works correctly on both 32-bit and 64-bit systems, unlike simple < 0
 * checks which fail on 32-bit when mmap returns high addresses like 0xf7ff1000
 */
#define MAX_ERRNO 4095
#define IS_SYSCALL_ERR(x) ((uintptr_t)(x) >= (uintptr_t)(-MAX_ERRNO))

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
