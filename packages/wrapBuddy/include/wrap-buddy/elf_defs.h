/*
 * elf_defs.h - ELF constants for wrapBuddy
 *
 * Shared between the freestanding loader and the C++ patcher tool.
 * These constants are the same across all architectures.
 *
 * Note: The C++ patcher can use <elf.h> for structures, but these
 * constants are provided for consistency and to avoid header conflicts.
 */

#pragma once

/* ELF class (e_ident[4]) */
#define ELFCLASS32 1
#define ELFCLASS64 2

/* ELF magic bytes */
#define ELF_MAGIC_0 0x7f
#define ELF_MAGIC_1 'E'
#define ELF_MAGIC_2 'L'
#define ELF_MAGIC_3 'F'

/* ELF segment types (p_type) */
#define PT_NULL 0
#define PT_LOAD 1
#define PT_DYNAMIC 2
#define PT_INTERP 3
#define PT_PHDR 6

/* ELF segment flags (p_flags) */
#define PF_X 1
#define PF_W 2
#define PF_R 4

/* Dynamic section tags (d_tag) */
#define DT_NULL 0
#define DT_STRTAB 5
#define DT_RUNPATH 29

/* Aux vector types (a_type) */
#define AT_NULL 0
#define AT_PHDR 3
#define AT_PHNUM 5
#define AT_PAGESZ 6
#define AT_BASE 7
#define AT_ENTRY 9
