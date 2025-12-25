/*
 * loader.c - External loader for wrapBuddy
 *
 * This loader is called by the stub. It:
 * 1. Reads config from /proc/self/exe + ".wrapbuddy"
 * 2. Restores original entry point bytes (mprotect + memcpy + mprotect)
 * 3. Sets DT_RUNPATH in a new .dynamic section (no LD_LIBRARY_PATH!)
 * 4. Loads the dynamic linker (ld.so)
 * 5. Jumps to ld.so with original entry point
 *
 * Build as flat binary:
 *   cc -nostdlib -fPIC -fno-stack-protector -Os \
 *      -Wl,-T,loader.ld -Wl,--oformat=binary \
 *      -o loader.bin loader.c
 */

#include "arch.h"
#include "config.h"
#include "debug.h"
#include "elf_defs.h"
#include "elf_types.h"
#include "freestanding.h"
#include "mmap.h"

enum { MAX_PATH = 512 };

/*
 * Build config path from /proc/self/exe
 * /path/to/binary -> /path/to/.binary.wrapbuddy
 */
static int build_config_path(char *buf, size_t bufsize) {
  intptr_t max_path_len = (intptr_t)bufsize - (1 + WRAPBUDDY_SUFFIX_LEN);
  if (max_path_len <= 0) {
    return -1;
  }

  intptr_t path_len = sys_readlink("/proc/self/exe", buf, max_path_len);
  if (path_len <= 0 || path_len >= max_path_len) {
    return -1;
  }

  /* Find last '/' to insert '.' before filename */
  intptr_t slash_pos = path_len - 1;
  while (slash_pos >= 0 && buf[slash_pos] != '/') {
    slash_pos--;
  }

  /* Move filename right by 1 to make room for '.' */
  intptr_t name_start = slash_pos + 1;
  intptr_t name_len = path_len - name_start;
  for (intptr_t idx = name_len - 1; idx >= 0; idx--) {
    // NOLINTNEXTLINE(clang-analyzer-core.uninitialized.Assign)
    buf[name_start + 1 + idx] = buf[name_start + idx];
  }
  buf[name_start] = '.';
  path_len++;

  /* Append ".wrapbuddy" */
  my_memcpy(buf + path_len, ".wrapbuddy", WRAPBUDDY_SUFFIX_LEN);
  return 0;
}

/*
 * Map config file into memory
 */
static void *map_config(const char *path, size_t *out_size) {
  intptr_t file_fd = sys_open(path, O_RDONLY);
  if (file_fd < 0) {
    return NULL;
  }

  struct stat statbuf;
  my_memset(&statbuf, 0, sizeof(statbuf));
  if (sys_fstat(file_fd, &statbuf) < 0) {
    sys_close(file_fd);
    return NULL;
  }

  void *mapped =
      (void *)sys_mmap(0, statbuf.st_size, PROT_READ, MAP_PRIVATE, file_fd, 0);
  sys_close(file_fd);

  if ((intptr_t)mapped < 0) {
    return NULL;
  }

  *out_size = statbuf.st_size;
  return mapped;
}

/*
 * Restore original bytes at entry point
 */
static int restore_entry_bytes(uintptr_t entry_vaddr, uintptr_t l_addr,
                               const char *orig_bytes, size_t size,
                               uintptr_t page_size) {
  uintptr_t page_mask = ~(page_size - 1);
  uintptr_t entry_runtime = l_addr + entry_vaddr;
  uintptr_t page_start = entry_runtime & page_mask;
  uintptr_t page_end = (entry_runtime + size + page_size - 1) & page_mask;
  size_t page_len = page_end - page_start;

  /* Make writable */
  intptr_t ret = sys_mprotect(page_start, page_len, PROT_READ | PROT_WRITE);
  if (ret < 0) {
    print("mprotect RW failed: ");
    print_hex(-ret);
    print("\n");
    return -1;
  }

  /* Restore original bytes */
  my_memcpy((void *)entry_runtime, orig_bytes, size);

  /* Make executable again */
  ret = sys_mprotect(page_start, page_len, PROT_READ | PROT_EXEC);
  if (ret < 0) {
    print("mprotect RX failed: ");
    print_hex(-ret);
    print("\n");
    return -1;
  }

  return 0;
}

/*
 * Validate ELF magic bytes
 */
static void validate_elf_magic(const ElfW(Ehdr) * ehdr) {
  if (ehdr->e_ident[0] != ELF_MAGIC_0 || ehdr->e_ident[1] != ELF_MAGIC_1 ||
      ehdr->e_ident[2] != ELF_MAGIC_2 || ehdr->e_ident[3] != ELF_MAGIC_3) {
    die("not an ELF file");
  }
}

/*
 * Find PT_LOAD range and return total size needed
 */
static size_t find_load_range(const ElfW(Phdr) * phdrs, int phnum,
                              uintptr_t page_size, uintptr_t *out_min_vaddr) {
  uintptr_t page_mask = ~(page_size - 1);
  uintptr_t min_vaddr = ~(uintptr_t)0;
  uintptr_t max_vaddr = 0;

  for (int idx = 0; idx < phnum; idx++) {
    if (phdrs[idx].p_type != PT_LOAD) {
      continue;
    }
    if (phdrs[idx].p_vaddr < min_vaddr) {
      min_vaddr = phdrs[idx].p_vaddr;
    }
    uintptr_t end = phdrs[idx].p_vaddr + phdrs[idx].p_memsz;
    if (end > max_vaddr) {
      max_vaddr = end;
    }
  }

  if (max_vaddr == 0) {
    die("interpreter has no PT_LOAD segments");
  }

  min_vaddr &= page_mask;
  max_vaddr = (max_vaddr + page_size - 1) & page_mask;
  *out_min_vaddr = min_vaddr;
  return max_vaddr - min_vaddr;
}

/*
 * Convert ELF p_flags to mmap prot flags
 */
static int prot_from_pflags(uint32_t pflags) {
  int prot = 0;
  if (pflags & PF_R) {
    prot |= PROT_READ;
  }
  if (pflags & PF_W) {
    prot |= PROT_WRITE;
  }
  if (pflags & PF_X) {
    prot |= PROT_EXEC;
  }
  return prot;
}

/*
 * Load a PT_LOAD segment from file to memory
 *
 * Strategy: map file content directly, then handle BSS separately.
 * For the BSS portion, we map anonymous memory since file-backed
 * mappings only cover filesz bytes.
 */
static void load_segment(const ElfW(Phdr) * phdr, intptr_t file_fd,
                         uintptr_t load_bias, uintptr_t page_size) {
  uintptr_t page_mask = ~(page_size - 1);
  uintptr_t vaddr = phdr->p_vaddr + load_bias;

  /* Page-align the file offset for mmap */
  uintptr_t offset_align = phdr->p_offset & (page_size - 1);
  uintptr_t map_offset = phdr->p_offset - offset_align;
  uintptr_t map_addr = vaddr - offset_align;

  /* Map file content */
  if (phdr->p_filesz > 0) {
    size_t map_size = phdr->p_filesz + offset_align;
    void *mapped =
        (void *)sys_mmap(map_addr, map_size, prot_from_pflags(phdr->p_flags),
                         MAP_PRIVATE | MAP_FIXED, file_fd, map_offset);
    if ((intptr_t)mapped < 0) {
      die("cannot map segment");
    }
  }

  /* Handle BSS: memory beyond file content.
   * BSS segments are always writable (they hold uninitialized data) */
  if (phdr->p_memsz > phdr->p_filesz) {
    if (!(phdr->p_flags & PF_W)) {
      die("BSS segment not writable (malformed ELF)");
    }
    uintptr_t bss_start = vaddr + phdr->p_filesz;
    uintptr_t bss_end = vaddr + phdr->p_memsz;
    uintptr_t file_map_end =
        (vaddr + phdr->p_filesz + page_size - 1) & page_mask;

    /* Zero BSS portion within the last page of file mapping */
    if (bss_start < file_map_end) {
      my_memset((void *)bss_start, 0, file_map_end - bss_start);
    }

    /* Map anonymous memory for BSS beyond file mapping */
    if (file_map_end < bss_end) {
      size_t anon_size = bss_end - file_map_end;
      void *anon = (void *)sys_mmap(
          file_map_end, anon_size, prot_from_pflags(phdr->p_flags),
          MAP_PRIVATE | MAP_FIXED | MAP_ANONYMOUS, -1, 0);
      if ((intptr_t)anon < 0) {
        die("cannot map BSS");
      }
    }
  }
}

/*
 * Load ELF interpreter into memory using mmap
 *
 * Maps the file once, then maps segments directly to their destinations.
 * No read() calls needed - the kernel handles page faults from file.
 */
static void *load_interp(const char *path, void **out_base,
                         uintptr_t page_size) {
  intptr_t file_fd = sys_open(path, O_RDONLY);
  if (file_fd < 0) {
    die("cannot open interpreter");
  }

  /* Get file size */
  struct stat statbuf;
  my_memset(&statbuf, 0, sizeof(statbuf));
  if (sys_fstat(file_fd, &statbuf) < 0) {
    die("cannot stat interpreter");
  }

  /* Map entire file to read headers */
  void *file =
      (void *)sys_mmap(0, statbuf.st_size, PROT_READ, MAP_PRIVATE, file_fd, 0);
  if ((intptr_t)file < 0) {
    die("cannot mmap interpreter");
  }

  ElfW(Ehdr) *ehdr = (ElfW(Ehdr) *)file;
  validate_elf_magic(ehdr);

  if (ehdr->e_phnum == 0) {
    die("interpreter has no program headers");
  }

  ElfW(Phdr) *phdrs = (ElfW(Phdr) *)((char *)file + ehdr->e_phoff);

  /* Find address range needed */
  uintptr_t min_vaddr;
  size_t total_size =
      find_load_range(phdrs, ehdr->e_phnum, page_size, &min_vaddr);

  /* Reserve contiguous address space */
  void *base = (void *)sys_mmap(0, total_size, PROT_NONE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((intptr_t)base < 0) {
    die("cannot reserve address space");
  }

  uintptr_t load_bias = (uintptr_t)base - min_vaddr;

  /* Load each PT_LOAD segment from file */
  for (int idx = 0; idx < ehdr->e_phnum; idx++) {
    if (phdrs[idx].p_type == PT_LOAD) {
      load_segment(&phdrs[idx], file_fd, load_bias, page_size);
    }
  }

  void *entry = (void *)(ehdr->e_entry + load_bias);

  sys_munmap(file, statbuf.st_size);
  sys_close(file_fd);

  *out_base = base;
  return entry;
}

/*
 * Find PT_DYNAMIC program header and return pointer to .dynamic section
 */
static ElfW(Dyn) * find_dynamic_section(ElfW(Phdr) * phdr, uintptr_t phnum,
                                        uintptr_t l_addr) {
  for (uintptr_t idx = 0; idx < phnum; idx++) {
    if (phdr[idx].p_type == PT_DYNAMIC) {
      return (ElfW(Dyn) *)(l_addr + phdr[idx].p_vaddr);
    }
  }
  return NULL;
}

/*
 * Find a dynamic entry by tag
 */
static ElfW(Dyn) * find_dyn_entry(ElfW(Dyn) * dyn, intptr_t tag) {
  for (; dyn->d_tag != DT_NULL; dyn++) {
    if (dyn->d_tag == tag) {
      return dyn;
    }
  }
  return NULL;
}

/*
 * Count dynamic entries (including DT_NULL terminator)
 */
static size_t count_dyn_entries(ElfW(Dyn) * dyn) {
  size_t count = 0;
  while (dyn[count].d_tag != DT_NULL) {
    count++;
  }
  return count + 1; /* Include DT_NULL */
}

/*
 * Set up RPATH by creating a new .dynamic section with DT_RUNPATH
 *
 * DT_RUNPATH stores an offset from DT_STRTAB, not an absolute address.
 * We point it to our rpath string in the mmap'd config file.
 *
 *   Main binary (loaded at l_addr)        Config file (mmap'd)
 *   +-------------------------+           +---------------------+
 *   | .strtab at vaddr V      |           | header              |
 *   | (runtime: V + l_addr)   |           | interp_path         |
 *   +-------------------------+           | rpath  <------------+--+
 *                                         +---------------------+  |
 *   New .dynamic (we create)                                       |
 *   +-------------------------+                                    |
 *   | DT_RUNPATH              |                                    |
 *   |   d_val = offset -------+------------------------------------+
 *   |         = rpath - (V + l_addr)
 *   +-------------------------+
 *
 * ld.so computes: (V + l_addr) + offset = rpath
 */
static ElfW(Dyn) * setup_rpath(ElfW(Dyn) * orig_dyn, const char *rpath,
                               uintptr_t l_addr, size_t *out_dyn_count) {
  /* Find DT_STRTAB - we need it to compute the offset */
  ElfW(Dyn) *strtab_entry = find_dyn_entry(orig_dyn, DT_STRTAB);
  if (!strtab_entry) {
    die("no DT_STRTAB found");
  }

  /* DT_STRTAB is a file vaddr; ld.so will add l_addr to get runtime addr */
  uintptr_t strtab_runtime = strtab_entry->d_un.d_ptr + l_addr;

  /* Count original entries and check if DT_RUNPATH exists */
  size_t orig_count = count_dyn_entries(orig_dyn);
  ElfW(Dyn) *runpath_entry = find_dyn_entry(orig_dyn, DT_RUNPATH);
  size_t new_count = runpath_entry ? orig_count : orig_count + 1;

  /* Allocate memory for new .dynamic section only (rpath is in config mmap) */
  size_t dyn_size = new_count * sizeof(ElfW(Dyn));

  ElfW(Dyn) *new_dyn = (ElfW(Dyn) *)sys_mmap(
      0, dyn_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((intptr_t)new_dyn < 0) {
    die("dynamic mmap failed");
  }

  /* Compute offset to rpath in config file (already mmap'd, never unmapped) */
  uintptr_t rpath_offset = (uintptr_t)rpath - strtab_runtime;

  /* Copy original .dynamic entries */
  size_t idx = 0;
  for (; orig_dyn[idx].d_tag != DT_NULL; idx++) {
    new_dyn[idx] = orig_dyn[idx];
    /* Update existing DT_RUNPATH if present */
    if (new_dyn[idx].d_tag == DT_RUNPATH) {
      new_dyn[idx].d_un.d_val = rpath_offset;
    }
  }

  /* Add new DT_RUNPATH if it didn't exist */
  if (!runpath_entry) {
    new_dyn[idx].d_tag = DT_RUNPATH;
    new_dyn[idx].d_un.d_val = rpath_offset;
    idx++;
  }

  /* Add DT_NULL terminator */
  new_dyn[idx].d_tag = DT_NULL;
  new_dyn[idx].d_un.d_val = 0;

  *out_dyn_count = new_count;
  return new_dyn;
}

static void auxv_set(ElfW(auxv_t) * auxv, uintptr_t type, uintptr_t value) {
  for (; auxv->a_type != AT_NULL; auxv++) {
    if (auxv->a_type == type) {
      auxv->a_un.a_val = value;
      return;
    }
  }
}

static uintptr_t auxv_get(ElfW(auxv_t) * auxv, uintptr_t type) {
  for (; auxv->a_type != AT_NULL; auxv++) {
    if (auxv->a_type == type) {
      return auxv->a_un.a_val;
    }
  }
  return 0;
}

/*
 * Main loader entry point
 * Called by stub with original stack pointer in first argument
 */
__attribute__((noreturn)) void loader_main(intptr_t *stack_ptr) {
  /* Map config file */
  char config_path[MAX_PATH];
  if (build_config_path(config_path, sizeof(config_path)) < 0) {
    die("cannot build config path");
  }

  size_t config_size;
  void *config_buf = map_config(config_path, &config_size);
  if (!config_buf) {
    die("cannot map config");
  }

  if (config_size < CONFIG_HEADER_SIZE) {
    die("config too small");
  }

  /* Parse config header */
  Config *cfg = (Config *)config_buf;

  /* Validate config field sizes are sane (prevents overflow in sum) */
  // NOLINTNEXTLINE(clang-analyzer-core.UndefinedBinaryOperatorResult)
  if (cfg->interp_len > config_size || cfg->rpath_len > config_size ||
      cfg->stub_size > config_size) {
    die("config truncated");
  }

  /* Now safe to sum - each component <= config_size, no overflow possible */
  size_t expected_size = CONFIG_HEADER_SIZE + (size_t)cfg->interp_len +
                         (size_t)cfg->rpath_len + (size_t)cfg->stub_size;
  if (expected_size > config_size) {
    die("config truncated");
  }

  /* Get pointers to config data */
  char *config_data = (char *)config_buf;
  char *interp_path = config_data + CONFIG_HEADER_SIZE;
  char *rpath = interp_path + cfg->interp_len;
  char *orig_bytes = rpath + cfg->rpath_len;

  /* Verify strings are null-terminated (lengths include the null byte) */
  if (cfg->interp_len == 0 || interp_path[cfg->interp_len - 1] != '\0') {
    die("invalid interp_path in config");
  }
  if (cfg->rpath_len == 0 || rpath[cfg->rpath_len - 1] != '\0') {
    die("invalid rpath in config");
  }

  /* Parse stack to find auxv */
  intptr_t argc = stack_ptr[0];
  char **envp = (char **)(stack_ptr + 1 + argc + 1);

  char **env_ptr = envp;
  while (*env_ptr) {
    env_ptr++;
  }
  ElfW(auxv_t) *auxv = (ElfW(auxv_t) *)(env_ptr + 1);

  /* Get page size from auxv */
  uintptr_t page_size = auxv_get(auxv, AT_PAGESZ);
  if (page_size == 0) {
    die("no AT_PAGESZ in auxv");
  }

  /* Calculate runtime load address (l_addr) */
  ElfW(Phdr) *orig_phdr = (ElfW(Phdr) *)auxv_get(auxv, AT_PHDR);
  uintptr_t orig_phnum = auxv_get(auxv, AT_PHNUM);

  if (!orig_phdr || orig_phnum == 0) {
    die("no AT_PHDR or AT_PHNUM in auxv");
  }

  uintptr_t l_addr = 0;
  int found_phdr = 0;
  for (uintptr_t idx = 0; idx < orig_phnum; idx++) {
    if (orig_phdr[idx].p_type == PT_PHDR) {
      l_addr = (uintptr_t)orig_phdr - orig_phdr[idx].p_vaddr;
      found_phdr = 1;
      break;
    }
  }
  if (!found_phdr) {
    die("no PT_PHDR found (required for PIE)");
  }

  /* Restore original entry point bytes */
  if (restore_entry_bytes(cfg->orig_entry, l_addr, orig_bytes, cfg->stub_size,
                          page_size) < 0) {
    die("cannot restore entry bytes");
  }

  /* Find and set up .dynamic section with RPATH */
  ElfW(Dyn) *orig_dyn = find_dynamic_section(orig_phdr, orig_phnum, l_addr);
  if (!orig_dyn) {
    die("no PT_DYNAMIC found");
  }

  size_t new_dyn_count;
  ElfW(Dyn) *new_dyn = setup_rpath(orig_dyn, rpath, l_addr, &new_dyn_count);

  /* Load interpreter */
  void *interp_base = NULL;
  void *interp_entry = load_interp(interp_path, &interp_base, page_size);

  /* Calculate real entry point */
  uintptr_t real_entry = l_addr + cfg->orig_entry;

  /* Build new program headers with PT_INTERP and updated PT_DYNAMIC
   * Note: This allocation must remain mapped - it's referenced via auxv
   * (AT_PHDR) throughout the process lifetime. */
  size_t interp_len = my_strlen(interp_path) + 1;
  size_t alloc_size = ((orig_phnum + 1) * sizeof(ElfW(Phdr))) + interp_len;
  char *alloc = (char *)sys_mmap(0, alloc_size, PROT_READ | PROT_WRITE,
                                 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((intptr_t)alloc < 0) {
    die("phdr mmap failed");
  }

  ElfW(Phdr) *new_phdr = (ElfW(Phdr) *)alloc;
  char *interp_str = alloc + ((orig_phnum + 1) * sizeof(ElfW(Phdr)));

  my_memcpy(new_phdr, orig_phdr, orig_phnum * sizeof(ElfW(Phdr)));
  my_memcpy(interp_str, interp_path, interp_len);

  /* Update PT_PHDR and PT_DYNAMIC to point to new locations */
  for (uintptr_t idx = 0; idx < orig_phnum; idx++) {
    if (new_phdr[idx].p_type == PT_PHDR) {
      new_phdr[idx].p_vaddr = (uintptr_t)new_phdr - l_addr;
      new_phdr[idx].p_paddr = new_phdr[idx].p_vaddr;
    } else if (new_phdr[idx].p_type == PT_DYNAMIC) {
      new_phdr[idx].p_vaddr = (uintptr_t)new_dyn - l_addr;
      new_phdr[idx].p_paddr = new_phdr[idx].p_vaddr;
      new_phdr[idx].p_filesz = new_dyn_count * sizeof(ElfW(Dyn));
      new_phdr[idx].p_memsz = new_phdr[idx].p_filesz;
    }
  }

  /* Add PT_INTERP */
  ElfW(Phdr) *interp_phdr = &new_phdr[orig_phnum];
  interp_phdr->p_type = PT_INTERP;
  interp_phdr->p_flags = PF_R;
  interp_phdr->p_offset = 0;
  interp_phdr->p_vaddr = (uintptr_t)interp_str - l_addr;
  interp_phdr->p_paddr = interp_phdr->p_vaddr;
  interp_phdr->p_filesz = interp_len;
  interp_phdr->p_memsz = interp_len;
  interp_phdr->p_align = 1;

  /* Update auxv - no trampoline needed, entry goes directly to real entry */
  auxv_set(auxv, AT_BASE, (uintptr_t)interp_base);
  auxv_set(auxv, AT_ENTRY, real_entry);
  auxv_set(auxv, AT_PHDR, (uintptr_t)new_phdr);
  auxv_set(auxv, AT_PHNUM, orig_phnum + 1);

  /* Jump to interpreter */
  JUMP_TO_ENTRY(stack_ptr, interp_entry);
  __builtin_unreachable();
}

DEFINE_START(loader_main)
