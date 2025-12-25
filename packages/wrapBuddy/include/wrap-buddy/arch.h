/*
 * arch.h - Architecture dispatcher for wrapBuddy
 *
 * Includes the correct architecture-specific header based on target.
 * Each arch header provides:
 *   - Syscall numbers (SYS_*)
 *   - Syscall wrappers (syscall0-syscall6)
 *   - Low-level primitives (PC_RELATIVE_ADDR, JUMP_*, DEFINE_START)
 *   - sys_open, sys_readlink portable wrappers
 *   - struct stat for the target architecture
 */

#pragma once

#include <wrap-buddy/freestanding.h>

#if defined(__x86_64__)
#include <wrap-buddy/arch/x86_64.h>
#elif defined(__aarch64__)
#include <wrap-buddy/arch/aarch64.h>
#elif defined(__i386__)
#include <wrap-buddy/arch/i386.h>
#else
#error "Unsupported architecture"
#endif

/*
 * Architecture-independent syscall wrappers
 */
#define sys_exit(code) syscall1(SYS_exit, code)
#define sys_close(fd) syscall1(SYS_close, fd)
#define sys_read(fd, buf, n) syscall3(SYS_read, fd, (intptr_t)(buf), n)
#define sys_write(fd, buf, n) syscall3(SYS_write, fd, (intptr_t)(buf), n)
#define sys_munmap(addr, len) syscall2(SYS_munmap, (intptr_t)(addr), len)

/*
 * sys_lseek - 64-bit seek
 *
 * i386 defines sys_lseek as a function using _llseek for large file support.
 * Other architectures use the regular lseek syscall which handles 64-bit.
 */
#if !defined(__i386__)
#define sys_lseek(fd, offset, whence) syscall3(SYS_lseek, fd, offset, whence)
#endif
#define sys_mprotect(addr, len, prot)                                          \
  syscall3(SYS_mprotect, (intptr_t)(addr), len, prot)

/*
 * sys_mmap - architecture-specific mmap wrapper
 *
 * i386 uses mmap2 which takes a page-aligned offset (offset >> 12).
 * x86_64 and aarch64 use mmap with byte offset.
 */
#if defined(__i386__)
#define sys_mmap(addr, len, prot, flags, fd, off)                              \
  syscall6(SYS_mmap2, (intptr_t)(addr), len, prot, flags, fd, (off) >> 12)
#else
#define sys_mmap(addr, len, prot, flags, fd, off)                              \
  syscall6(SYS_mmap, (intptr_t)(addr), len, prot, flags, fd, off)
#endif

/*
 * sys_fstat - architecture-specific fstat wrapper
 *
 * i386 uses fstat64 for large file support.
 * x86_64 and aarch64 use fstat.
 */
#if defined(__i386__)
#define sys_fstat(fd, statbuf) syscall2(SYS_fstat64, fd, (intptr_t)(statbuf))
#else
#define sys_fstat(fd, statbuf) syscall2(SYS_fstat, fd, (intptr_t)(statbuf))
#endif
