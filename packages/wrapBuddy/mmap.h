/*
 * mmap.h - mmap and file constants for freestanding code
 *
 * These values are the same on all Linux architectures.
 */

#pragma once

/* File open flags */
#define O_RDONLY 0

/* mmap protection flags */
#define PROT_NONE 0
#define PROT_READ 1
#define PROT_WRITE 2
#define PROT_EXEC 4

/* mmap flags */
#define MAP_PRIVATE 2
#define MAP_FIXED 0x10
#define MAP_ANONYMOUS 0x20
