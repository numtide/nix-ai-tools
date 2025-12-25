/*
 * arch.h - Architecture-specific definitions for wrapBuddy
 *
 * Syscall wrappers, entry points, and low-level primitives.
 * Currently supports: x86_64, aarch64
 */

#pragma once

#include "types.h"

#if defined(__x86_64__)

/*
 * x86_64 syscall numbers
 */
#define SYS_read 0
#define SYS_write 1
#define SYS_open 2
#define SYS_close 3
#define SYS_fstat 5
#define SYS_lseek 8
#define SYS_mmap 9
#define SYS_mprotect 10
#define SYS_munmap 11
#define SYS_exit 60
#define SYS_readlink 89

/*
 * x86_64 syscall wrappers
 */
static inline int64_t syscall0(int64_t n) {
  int64_t ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(n) : "rcx", "r11", "memory");
  return ret;
}

static inline int64_t syscall1(int64_t n, int64_t a1) {
  int64_t ret;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1)
                   : "rcx", "r11", "memory");
  return ret;
}

static inline int64_t syscall2(int64_t n, int64_t a1, int64_t a2) {
  int64_t ret;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1), "S"(a2)
                   : "rcx", "r11", "memory");
  return ret;
}

static inline int64_t syscall3(int64_t n, int64_t a1, int64_t a2, int64_t a3) {
  int64_t ret;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1), "S"(a2), "d"(a3)
                   : "rcx", "r11", "memory");
  return ret;
}

static inline int64_t syscall6(int64_t n, int64_t a1, int64_t a2, int64_t a3,
                               int64_t a4, int64_t a5, int64_t a6) {
  int64_t ret;
  register int64_t r10 __asm__("r10") = a4;
  register int64_t r8 __asm__("r8") = a5;
  register int64_t r9 __asm__("r9") = a6;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8),
                     "r"(r9)
                   : "rcx", "r11", "memory");
  return ret;
}

/*
 * x86_64 low-level primitives
 */

/* Get address of symbol using PC-relative addressing */
#define PC_RELATIVE_ADDR(result, symbol)                                       \
  __asm__("lea %1, %0" : "=r"(result) : "m"(symbol))

/* Jump to target with stack pointer restored */
#define JUMP_WITH_SP(sp, target)                                               \
  __asm__ volatile("mov %0, %%rsp\n"                                           \
                   "jmp *%1\n"                                                 \
                   :                                                           \
                   : "r"(sp), "r"(target)                                      \
                   : "memory")

/* Jump to entry point (for ld.so), zeros rdx per ABI */
#define JUMP_TO_ENTRY(sp, entry)                                               \
  __asm__ volatile("mov %0, %%rsp\n"                                           \
                   "xor %%rdx, %%rdx\n"                                        \
                   "jmp *%1\n"                                                 \
                   :                                                           \
                   : "r"(sp), "r"(entry)                                       \
                   : "memory")

/* Entry point wrapper - use file-scope asm for clang compatibility */
#define DEFINE_START(main_func)                                                \
  __asm__(".section .text._start\n"                                            \
          ".global _start\n"                                                   \
          ".type _start, @function\n"                                          \
          "_start:\n"                                                          \
          "    xor %rbp, %rbp\n"                                               \
          "    mov %rsp, %rdi\n"                                               \
          "    and $-16, %rsp\n"                                               \
          "    call " #main_func "\n"                                          \
          ".size _start, .-_start\n");

/* Portable syscall wrappers */
#define sys_open(path, flags) syscall2(SYS_open, (int64_t)(path), flags)
#define sys_readlink(path, buf, size)                                          \
  syscall3(SYS_readlink, (int64_t)(path), (int64_t)(buf), size)

#elif defined(__aarch64__)

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
 */
static inline int64_t syscall0(int64_t n) {
  register int64_t x8 __asm__("x8") = n;
  register int64_t x0 __asm__("x0");
  __asm__ volatile("svc #0" : "=r"(x0) : "r"(x8) : "memory");
  return x0;
}

static inline int64_t syscall1(int64_t n, int64_t a1) {
  register int64_t x8 __asm__("x8") = n;
  register int64_t x0 __asm__("x0") = a1;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8) : "memory");
  return x0;
}

static inline int64_t syscall2(int64_t n, int64_t a1, int64_t a2) {
  register int64_t x8 __asm__("x8") = n;
  register int64_t x0 __asm__("x0") = a1;
  register int64_t x1 __asm__("x1") = a2;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1) : "memory");
  return x0;
}

static inline int64_t syscall3(int64_t n, int64_t a1, int64_t a2, int64_t a3) {
  register int64_t x8 __asm__("x8") = n;
  register int64_t x0 __asm__("x0") = a1;
  register int64_t x1 __asm__("x1") = a2;
  register int64_t x2 __asm__("x2") = a3;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2) : "memory");
  return x0;
}

static inline int64_t syscall4(int64_t n, int64_t a1, int64_t a2, int64_t a3,
                               int64_t a4) {
  register int64_t x8 __asm__("x8") = n;
  register int64_t x0 __asm__("x0") = a1;
  register int64_t x1 __asm__("x1") = a2;
  register int64_t x2 __asm__("x2") = a3;
  register int64_t x3 __asm__("x3") = a4;
  __asm__ volatile("svc #0"
                   : "+r"(x0)
                   : "r"(x8), "r"(x1), "r"(x2), "r"(x3)
                   : "memory");
  return x0;
}

static inline int64_t syscall6(int64_t n, int64_t a1, int64_t a2, int64_t a3,
                               int64_t a4, int64_t a5, int64_t a6) {
  register int64_t x8 __asm__("x8") = n;
  register int64_t x0 __asm__("x0") = a1;
  register int64_t x1 __asm__("x1") = a2;
  register int64_t x2 __asm__("x2") = a3;
  register int64_t x3 __asm__("x3") = a4;
  register int64_t x4 __asm__("x4") = a5;
  register int64_t x5 __asm__("x5") = a6;
  __asm__ volatile("svc #0"
                   : "+r"(x0)
                   : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5)
                   : "memory");
  return x0;
}

/*
 * aarch64 low-level primitives
 * Uses adr (±1MB range) instead of adrp+add which has page alignment issues
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
  syscall4(SYS_openat, AT_FDCWD, (int64_t)(path), flags, 0)
#define sys_readlink(path, buf, size)                                          \
  syscall4(SYS_readlinkat, AT_FDCWD, (int64_t)(path), (int64_t)(buf), size)

#else
#error "Unsupported architecture"
#endif

/*
 * Architecture-independent syscall wrappers
 */
#define sys_exit(code) syscall1(SYS_exit, code)
#define sys_close(fd) syscall1(SYS_close, fd)
#define sys_read(fd, buf, n) syscall3(SYS_read, fd, (int64_t)(buf), n)
#define sys_write(fd, buf, n) syscall3(SYS_write, fd, (int64_t)(buf), n)
#define sys_lseek(fd, offset, whence) syscall3(SYS_lseek, fd, offset, whence)
#define sys_fstat(fd, statbuf) syscall2(SYS_fstat, fd, (int64_t)(statbuf))
#define sys_mmap(addr, len, prot, flags, fd, off)                              \
  syscall6(SYS_mmap, (int64_t)(addr), len, prot, flags, fd, off)
#define sys_munmap(addr, len) syscall2(SYS_munmap, (int64_t)(addr), len)
#define sys_mprotect(addr, len, prot)                                          \
  syscall3(SYS_mprotect, (int64_t)(addr), len, prot)
