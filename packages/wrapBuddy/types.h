/*
 * types.h - Basic types and constants for wrapBuddy
 *
 * Uses freestanding C headers for basic types.
 */

#pragma once

/* Freestanding headers - provided by compiler, not libc */
#include <stddef.h>
#include <stdint.h>

/* ssize_t is not in freestanding headers */
typedef long ssize_t;

/* Memory constants */
#define PAGE_SIZE 4096
#define PAGE_MASK (~((uint64_t)PAGE_SIZE - 1))

/* File constants */
#define O_RDONLY 0
#define SEEK_SET 0

/* Error numbers */
#define EINTR 4

/* mmap constants */
#define PROT_READ 1
#define PROT_WRITE 2
#define PROT_EXEC 4
#define MAP_PRIVATE 2
#define MAP_ANONYMOUS 0x20

/* ELF constants */
#define PT_NULL 0
#define PT_LOAD 1
#define PT_DYNAMIC 2
#define PT_INTERP 3
#define PT_PHDR 6
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
#define AT_BASE 7
#define AT_ENTRY 9

/*
 * ELF structures
 */

typedef struct {
  unsigned char e_ident[16];
  uint16_t e_type;
  uint16_t e_machine;
  uint32_t e_version;
  uint64_t e_entry;
  uint64_t e_phoff;
  uint64_t e_shoff;
  uint32_t e_flags;
  uint16_t e_ehsize;
  uint16_t e_phentsize;
  uint16_t e_phnum;
  uint16_t e_shentsize;
  uint16_t e_shnum;
  uint16_t e_shstrndx;
} Elf64_Ehdr;

typedef struct {
  uint32_t p_type;
  uint32_t p_flags;
  uint64_t p_offset;
  uint64_t p_vaddr;
  uint64_t p_paddr;
  uint64_t p_filesz;
  uint64_t p_memsz;
  uint64_t p_align;
} Elf64_Phdr;

typedef struct {
  uint64_t a_type;
  union {
    uint64_t a_val;
  } a_un;
} Elf64_auxv_t;

typedef struct {
  int64_t d_tag;
  union {
    uint64_t d_val;
    uint64_t d_ptr;
  } d_un;
} Elf64_Dyn;

/*
 * Full stat structure - kernel writes all 144 bytes
 * Layout matches Linux x86_64/aarch64 kernel struct stat
 */
struct stat {
  uint64_t st_dev;
  uint64_t st_ino;
  uint64_t st_nlink;
  uint32_t st_mode;
  uint32_t st_uid;
  uint32_t st_gid;
  uint32_t __pad0;
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
  int64_t __unused[3];
};

