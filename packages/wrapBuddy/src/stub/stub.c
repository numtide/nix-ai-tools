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

#include <wrap-buddy/freestanding.h>

#include <wrap-buddy/arch.h>
#include <wrap-buddy/debug.h>
#include <wrap-buddy/mmap.h>

#ifndef LOADER_PATH
#error "LOADER_PATH must be defined"
#endif

/* Mark as used to prevent optimization when referenced only via inline asm */
static const char loader_path[] __attribute__((used)) = LOADER_PATH;

__attribute__((noreturn)) void stub_main(const intptr_t *const stack_ptr) {
  /* Get loader path using PC-relative addressing */
  const char *path;
  PC_RELATIVE_ADDR(path, loader_path);

  /* Open loader binary */
  intptr_t file_desc = sys_open(path, O_RDONLY);
  if (file_desc < 0) {
    die("open loader");
  }

  /* Get actual loader size */
  struct stat file_stat;
  if (sys_fstat(file_desc, &file_stat) < 0) {
    die("fstat loader");
  }

  /* mmap loader as flat binary (entry at offset 0)
   * Note: This mapping is intentionally never unmapped and remains
   * until process exit. Could be reclaimed via trampoline but not worth
   * the complexity. */
  // NOLINTNEXTLINE(clang-analyzer-core.CallAndMessage)
  void *loader = (void *)sys_mmap(0,                     /* addr = NULL */
                                  file_stat.st_size,     /* len */
                                  PROT_READ | PROT_EXEC, /* prot */
                                  MAP_PRIVATE,           /* flags */
                                  file_desc,             /* fd */
                                  0                      /* offset */
  );
  if (IS_SYSCALL_ERR((intptr_t)loader)) {
    die("mmap loader");
  }

  sys_close(file_desc);

  /* Jump to loader with original stack pointer restored */
  JUMP_WITH_SP(stack_ptr, loader);
  __builtin_unreachable();
}

DEFINE_START(stub_main)
