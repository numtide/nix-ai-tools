/*
 * arch/x86_64.h - x86_64-specific definitions for wrapBuddy
 *
 * Syscall wrappers, entry points, and stat structure for x86_64 Linux.
 */

#pragma once

#include <wrap-buddy/freestanding.h> // IWYU pragma: export

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
 *
 * Uses syscall instruction with arguments in rdi, rsi, rdx, r10, r8, r9.
 * Syscall number in rax, return value in rax.
 */
static inline intptr_t syscall0(intptr_t n) {
  intptr_t ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(n) : "rcx", "r11", "memory");
  return ret;
}

static inline intptr_t syscall1(intptr_t n, intptr_t a1) {
  intptr_t ret;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1)
                   : "rcx", "r11", "memory");
  return ret;
}

static inline intptr_t syscall2(intptr_t n, intptr_t a1, intptr_t a2) {
  intptr_t ret;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1), "S"(a2)
                   : "rcx", "r11", "memory");
  return ret;
}

static inline intptr_t syscall3(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3) {
  intptr_t ret;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a1), "S"(a2), "d"(a3)
                   : "rcx", "r11", "memory");
  return ret;
}

static inline intptr_t syscall6(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3, intptr_t a4, intptr_t a5,
                                intptr_t a6) {
  intptr_t ret;
  register intptr_t r10 __asm__("r10") = a4;
  register intptr_t r8 __asm__("r8") = a5;
  register intptr_t r9 __asm__("r9") = a6;
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
#define sys_open(path, flags) syscall2(SYS_open, (intptr_t)(path), flags)
#define sys_readlink(path, buf, size)                                          \
  syscall3(SYS_readlink, (intptr_t)(path), (intptr_t)(buf), size)

/*
 * x86_64 stat structure
 * Layout matches Linux x86_64 kernel struct stat (144 bytes)
 */
struct stat {
  uint64_t st_dev;
  uint64_t st_ino;
  uint64_t st_nlink;
  uint32_t st_mode;
  uint32_t st_uid;
  uint32_t st_gid;
  uint32_t pad0_;
  uint64_t st_rdev;
  int64_t st_size;
  int64_t st_blksize;
  int64_t st_blocks;
  uint64_t st_atime;
  uint64_t st_atime_nsec;
  uint64_t st_mtime;
  uint64_t st_mtime_nsec;
  uint64_t st_ctime;
  uint64_t st_ctime_nsec;
  int64_t reserved_[3];
};
