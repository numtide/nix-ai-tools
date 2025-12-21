/*
 * stub.c - Minimal entry stub for wrapBuddy
 *
 * This tiny stub (~200 bytes) is written to the binary's entry point.
 * It loads the external loader and jumps to it.
 *
 * Build as flat binary:
 *   cc -nostdlib -fPIC -fno-stack-protector -Os \
 *      -DLOADER_PATH='"/nix/store/.../loader"' \
 *      -Wl,-T,stub.ld -Wl,--oformat=binary \
 *      -o stub.bin stub.c
 */

#include "common.h"

#ifndef LOADER_PATH
#error "LOADER_PATH must be defined"
#endif

static const char loader_path[] = LOADER_PATH;

__attribute__((noreturn)) void stub_main(int64_t *sp) {
  /* Get loader path using PC-relative addressing */
  const char *path;
  PC_RELATIVE_ADDR(path, loader_path);

  /* Open loader binary */
  int64_t fd = sys_open(path, O_RDONLY);
  if (fd < 0)
    die("open loader");

  /* Get actual loader size */
  struct stat st;
  if (sys_fstat(fd, &st) < 0)
    die("fstat loader");

  /* mmap loader as flat binary (entry at offset 0)
   * Note: This mapping is intentionally never unmapped and remains
   * until process exit. Could be reclaimed via trampoline but not worth
   * the complexity. */
  void *loader = (void *)sys_mmap(0,                     /* addr = NULL */
                                  st.st_size,            /* len */
                                  PROT_READ | PROT_EXEC, /* prot */
                                  MAP_PRIVATE,           /* flags */
                                  fd,                    /* fd */
                                  0                      /* offset */
  );
  if ((int64_t)loader < 0)
    die("mmap loader");

  sys_close(fd);

  /* Jump to loader with original stack pointer restored */
  JUMP_WITH_SP(sp, loader);
  __builtin_unreachable();
}

DEFINE_START(stub_main)
