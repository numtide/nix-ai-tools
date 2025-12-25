/*
 * common.h - Common utilities for wrapBuddy stub and loader
 *
 * Includes architecture-specific code and provides portable utilities.
 */

#pragma once

#include "arch.h"
#include "types.h"

/*
 * Architecture-independent constants
 */

/* File constants */
#define O_RDONLY 0
#define SEEK_SET 0

/* Error numbers */
#define EINTR 4

/* mmap constants - same on all Linux architectures */
#define PROT_NONE 0
#define PROT_READ 1
#define PROT_WRITE 2
#define PROT_EXEC 4
#define MAP_PRIVATE 2
#define MAP_FIXED 0x10
#define MAP_ANONYMOUS 0x20

/* ELF segment types */
#define PT_NULL 0
#define PT_LOAD 1
#define PT_DYNAMIC 2
#define PT_INTERP 3
#define PT_PHDR 6

/* ELF segment flags */
#define PF_X 1
#define PF_W 2
#define PF_R 4

/* Dynamic section tags */
#define DT_NULL 0
#define DT_STRTAB 5
#define DT_RUNPATH 29

/* Aux vector types */
#define AT_NULL 0
#define AT_PHDR 3
#define AT_PHNUM 5
#define AT_PAGESZ 6
#define AT_BASE 7
#define AT_ENTRY 9

/* ELF magic bytes */
#define ELF_MAGIC_0 0x7f
#define ELF_MAGIC_1 'E'
#define ELF_MAGIC_2 'L'
#define ELF_MAGIC_3 'F'

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

static inline void print_hex(uintptr_t val) {
  /* Buffer size: "0x" + hex digits + null terminator
   * 32-bit: 2 + 8 + 1 = 11, 64-bit: 2 + 16 + 1 = 19 */
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
