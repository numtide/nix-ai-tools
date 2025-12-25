/*
 * arch/aarch64.h - aarch64-specific definitions for wrapBuddy
 *
 * Syscall wrappers, entry points, and stat structure for aarch64 Linux.
 */

#pragma once

#include "../freestanding.h"

/*
 * aarch64 syscall numbers
 */
#define SYS_read 63
#define SYS_write 64
#define SYS_openat 56
#define SYS_close 57
#define SYS_fstat 80
#define SYS_lseek 62
#define SYS_mmap 222
#define SYS_munmap 215
#define SYS_mprotect 226
#define SYS_exit 93
#define SYS_readlinkat 78

#define AT_FDCWD -100

/*
 * aarch64 syscall wrappers
 *
 * Uses svc #0 instruction with arguments in x0-x5.
 * Syscall number in x8, return value in x0.
 */
static inline intptr_t syscall0(intptr_t n) {
  register intptr_t x8 __asm__("x8") = n;
  register intptr_t x0 __asm__("x0");
  __asm__ volatile("svc #0" : "=r"(x0) : "r"(x8) : "memory");
  return x0;
}

static inline intptr_t syscall1(intptr_t n, intptr_t a1) {
  register intptr_t x8 __asm__("x8") = n;
  register intptr_t x0 __asm__("x0") = a1;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8) : "memory");
  return x0;
}

static inline intptr_t syscall2(intptr_t n, intptr_t a1, intptr_t a2) {
  register intptr_t x8 __asm__("x8") = n;
  register intptr_t x0 __asm__("x0") = a1;
  register intptr_t x1 __asm__("x1") = a2;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1) : "memory");
  return x0;
}

static inline intptr_t syscall3(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3) {
  register intptr_t x8 __asm__("x8") = n;
  register intptr_t x0 __asm__("x0") = a1;
  register intptr_t x1 __asm__("x1") = a2;
  register intptr_t x2 __asm__("x2") = a3;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2) : "memory");
  return x0;
}

static inline intptr_t syscall4(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3, intptr_t a4) {
  register intptr_t x8 __asm__("x8") = n;
  register intptr_t x0 __asm__("x0") = a1;
  register intptr_t x1 __asm__("x1") = a2;
  register intptr_t x2 __asm__("x2") = a3;
  register intptr_t x3 __asm__("x3") = a4;
  __asm__ volatile("svc #0"
                   : "+r"(x0)
                   : "r"(x8), "r"(x1), "r"(x2), "r"(x3)
                   : "memory");
  return x0;
}

static inline intptr_t syscall6(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3, intptr_t a4, intptr_t a5,
                                intptr_t a6) {
  register intptr_t x8 __asm__("x8") = n;
  register intptr_t x0 __asm__("x0") = a1;
  register intptr_t x1 __asm__("x1") = a2;
  register intptr_t x2 __asm__("x2") = a3;
  register intptr_t x3 __asm__("x3") = a4;
  register intptr_t x4 __asm__("x4") = a5;
  register intptr_t x5 __asm__("x5") = a6;
  __asm__ volatile("svc #0"
                   : "+r"(x0)
                   : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5)
                   : "memory");
  return x0;
}

/*
 * aarch64 low-level primitives
 * Uses adr (+-1MB range) instead of adrp+add which has page alignment issues
 */

/* Get address of symbol using PC-relative addressing */
#define PC_RELATIVE_ADDR(result, symbol)                                       \
  __asm__("adr %0, %1" : "=r"(result) : "S"(&symbol))

/* Jump to target with stack pointer restored */
#define JUMP_WITH_SP(sp, target)                                               \
  __asm__ volatile("mov sp, %0\n"                                              \
                   "br %1\n"                                                   \
                   :                                                           \
                   : "r"(sp), "r"(target)                                      \
                   : "memory")

/* Jump to entry point (for ld.so), zeros x0 per ABI */
#define JUMP_TO_ENTRY(sp, entry)                                               \
  __asm__ volatile("mov sp, %0\n"                                              \
                   "mov x0, #0\n"                                              \
                   "br %1\n"                                                   \
                   :                                                           \
                   : "r"(sp), "r"(entry)                                       \
                   : "memory")

/* Entry point wrapper - use file-scope asm since naked is not supported */
#define DEFINE_START(main_func)                                                \
  __asm__(".section .text._start\n"                                            \
          ".global _start\n"                                                   \
          ".type _start, %function\n"                                          \
          "_start:\n"                                                          \
          "    mov x29, #0\n"                                                  \
          "    mov x30, #0\n"                                                  \
          "    mov x0, sp\n"                                                   \
          "    and sp, x0, #-16\n"                                             \
          "    bl " #main_func "\n"                                            \
          ".size _start, .-_start\n");

/* Portable syscall wrappers - aarch64 uses *at variants */
#define sys_open(path, flags)                                                  \
  syscall4(SYS_openat, AT_FDCWD, (intptr_t)(path), flags, 0)
#define sys_readlink(path, buf, size)                                          \
  syscall4(SYS_readlinkat, AT_FDCWD, (intptr_t)(path), (intptr_t)(buf), size)

/*
 * aarch64 stat structure
 * Layout matches Linux aarch64 kernel struct stat (128 bytes)
 */
struct stat {
  uint64_t st_dev;
  uint64_t st_ino;
  uint32_t st_mode;
  uint32_t st_nlink;
  uint32_t st_uid;
  uint32_t st_gid;
  uint64_t st_rdev;
  uint64_t pad1_;
  int64_t st_size;
  int32_t st_blksize;
  int32_t pad2_;
  int64_t st_blocks;
  int64_t st_atime;
  uint64_t st_atime_nsec;
  int64_t st_mtime;
  uint64_t st_mtime_nsec;
  int64_t st_ctime;
  uint64_t st_ctime_nsec;
  uint32_t unused_[2];
};
