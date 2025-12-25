/*
 * types.h - Basic types and ELF structures for wrapBuddy
 *
 * Uses freestanding C headers for basic types.
 * Provides both 32-bit and 64-bit ELF structures with ElfW() macros.
 */

#pragma once

/* Freestanding headers - provided by compiler, not libc */
#include <stddef.h>
#include <stdint.h>

/* ssize_t is not in freestanding headers */
typedef long ssize_t;

/* Pointer-sized types for architecture independence */
typedef __UINTPTR_TYPE__ uintptr_t;
typedef __INTPTR_TYPE__ intptr_t;

/*
 * ELF class detection and ElfW() macro
 * ElfW(type) expands to Elf32_type or Elf64_type based on pointer size
 */
#if __SIZEOF_POINTER__ == 8
#define ELFCLASS64 1
#define ElfW(type) Elf64_##type
#else
#define ELFCLASS32 1
#define ElfW(type) Elf32_##type
#endif

/*
 * 64-bit ELF structures
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
 * 32-bit ELF structures
 */

typedef struct {
  unsigned char e_ident[16];
  uint16_t e_type;
  uint16_t e_machine;
  uint32_t e_version;
  uint32_t e_entry;
  uint32_t e_phoff;
  uint32_t e_shoff;
  uint32_t e_flags;
  uint16_t e_ehsize;
  uint16_t e_phentsize;
  uint16_t e_phnum;
  uint16_t e_shentsize;
  uint16_t e_shnum;
  uint16_t e_shstrndx;
} Elf32_Ehdr;

typedef struct {
  uint32_t p_type;
  uint32_t p_offset;
  uint32_t p_vaddr;
  uint32_t p_paddr;
  uint32_t p_filesz;
  uint32_t p_memsz;
  uint32_t p_flags;
  uint32_t p_align;
} Elf32_Phdr;

typedef struct {
  uint32_t a_type;
  union {
    uint32_t a_val;
  } a_un;
} Elf32_auxv_t;

typedef struct {
  int32_t d_tag;
  union {
    uint32_t d_val;
    uint32_t d_ptr;
  } d_un;
} Elf32_Dyn;
