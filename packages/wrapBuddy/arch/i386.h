/*
 * arch/i386.h - i386-specific definitions for wrapBuddy
 *
 * Syscall wrappers, entry points, and stat structure for i386 Linux.
 */

#pragma once

#include "../freestanding.h"

/*
 * i386 syscall numbers
 */
#define SYS_exit 1
#define SYS_read 3
#define SYS_write 4
#define SYS_open 5
#define SYS_close 6
#define SYS_lseek 19
#define SYS_mmap2 192
#define SYS_mprotect 125
#define SYS_munmap 91
#define SYS_readlink 85
#define SYS_fstat64 197

/*
 * i386 syscall wrappers
 *
 * Uses int $0x80 with arguments in ebx, ecx, edx, esi, edi, ebp.
 * Syscall number in eax, return value in eax.
 *
 * Note: For 6-argument syscalls, ebp must be saved/restored since
 * it's the frame pointer and the caller may need it.
 */
static inline intptr_t syscall0(intptr_t n) {
  intptr_t ret;
  __asm__ volatile("int $0x80" : "=a"(ret) : "a"(n) : "memory");
  return ret;
}

static inline intptr_t syscall1(intptr_t n, intptr_t a1) {
  intptr_t ret;
  __asm__ volatile("int $0x80" : "=a"(ret) : "a"(n), "b"(a1) : "memory");
  return ret;
}

static inline intptr_t syscall2(intptr_t n, intptr_t a1, intptr_t a2) {
  intptr_t ret;
  __asm__ volatile("int $0x80"
                   : "=a"(ret)
                   : "a"(n), "b"(a1), "c"(a2)
                   : "memory");
  return ret;
}

static inline intptr_t syscall3(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3) {
  intptr_t ret;
  __asm__ volatile("int $0x80"
                   : "=a"(ret)
                   : "a"(n), "b"(a1), "c"(a2), "d"(a3)
                   : "memory");
  return ret;
}

static inline intptr_t syscall4(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3, intptr_t a4) {
  intptr_t ret;
  __asm__ volatile("int $0x80"
                   : "=a"(ret)
                   : "a"(n), "b"(a1), "c"(a2), "d"(a3), "S"(a4)
                   : "memory");
  return ret;
}

static inline intptr_t syscall5(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3, intptr_t a4, intptr_t a5) {
  intptr_t ret;
  __asm__ volatile("int $0x80"
                   : "=a"(ret)
                   : "a"(n), "b"(a1), "c"(a2), "d"(a3), "S"(a4), "D"(a5)
                   : "memory");
  return ret;
}

static inline intptr_t syscall6(intptr_t n, intptr_t a1, intptr_t a2,
                                intptr_t a3, intptr_t a4, intptr_t a5,
                                intptr_t a6) {
  intptr_t ret;
  /* Save ebp, use it for 6th arg, then restore */
  __asm__ volatile("push %%ebp\n"
                   "mov %7, %%ebp\n"
                   "int $0x80\n"
                   "pop %%ebp\n"
                   : "=a"(ret)
                   : "a"(n), "b"(a1), "c"(a2), "d"(a3), "S"(a4), "D"(a5),
                     "m"(a6)
                   : "memory");
  return ret;
}

/*
 * i386 low-level primitives
 */

/* Get address of symbol using PC-relative addressing via call/pop */
#define PC_RELATIVE_ADDR(result, symbol)                                       \
  __asm__("call 1f\n"                                                          \
          "1: pop %0\n"                                                        \
          "add $(" #symbol " - 1b), %0"                                        \
          : "=r"(result))

/* Jump to target with stack pointer restored */
#define JUMP_WITH_SP(sp, target)                                               \
  __asm__ volatile("mov %0, %%esp\n"                                           \
                   "jmp *%1\n"                                                 \
                   :                                                           \
                   : "r"(sp), "r"(target)                                      \
                   : "memory")

/* Jump to entry point (for ld.so), zeros edx per ABI */
#define JUMP_TO_ENTRY(sp, entry)                                               \
  __asm__ volatile("mov %0, %%esp\n"                                           \
                   "xor %%edx, %%edx\n"                                        \
                   "jmp *%1\n"                                                 \
                   :                                                           \
                   : "r"(sp), "r"(entry)                                       \
                   : "memory")

/* Entry point wrapper */
#define DEFINE_START(main_func)                                                \
  __asm__(".section .text._start\n"                                            \
          ".global _start\n"                                                   \
          ".type _start, @function\n"                                          \
          "_start:\n"                                                          \
          "    xor %ebp, %ebp\n"                                               \
          "    mov %esp, %eax\n"                                               \
          "    and $-16, %esp\n"                                               \
          "    push %eax\n"                                                    \
          "    call " #main_func "\n"                                          \
          ".size _start, .-_start\n");

/* Portable syscall wrappers */
#define sys_open(path, flags) syscall2(SYS_open, (intptr_t)(path), flags)
#define sys_readlink(path, buf, size)                                          \
  syscall3(SYS_readlink, (intptr_t)(path), (intptr_t)(buf), size)

/*
 * i386 uses fstat64 for proper large file support.
 * Layout matches Linux i386 kernel struct stat64 (96 bytes)
 */
struct stat {
  uint64_t st_dev;
  uint32_t pad1_;
  uint32_t st_ino_low;
  uint32_t st_mode;
  uint32_t st_nlink;
  uint32_t st_uid;
  uint32_t st_gid;
  uint64_t st_rdev;
  uint32_t pad2_;
  int64_t st_size;
  int32_t st_blksize;
  int64_t st_blocks;
  int32_t st_atime;
  uint32_t st_atime_nsec;
  int32_t st_mtime;
  uint32_t st_mtime_nsec;
  int32_t st_ctime;
  uint32_t st_ctime_nsec;
  uint64_t st_ino;
};
