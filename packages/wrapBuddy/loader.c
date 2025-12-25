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
 * Config file format (binary):
 *   uint64_t orig_entry     - original entry point (ELF vaddr)
 *   uint64_t stub_size      - size of stub that was overwritten
 *   uint16_t interp_len     - length of interpreter path (including null)
 *   uint16_t rpath_len      - length of RPATH string (including null)
 *   char interp_path[]      - interpreter path (null-terminated)
 *   char rpath[]            - colon-separated library paths (null-terminated)
 *   char orig_bytes[]       - original bytes that were overwritten
 *
 * Build as flat binary:
 *   cc -nostdlib -fPIC -fno-stack-protector -Os \
 *      -Wl,-T,loader.ld -Wl,--oformat=binary \
 *      -o loader.bin loader.c
 */

#include "common.h"

/* Config file header */
struct Config {
  uint64_t orig_entry;
  uint64_t stub_size;
  uint16_t interp_len;
  uint16_t rpath_len;
  /* Followed by: interp_path, rpath, orig_bytes */
};

enum {
  CONFIG_HEADER_SIZE = 20,
  MAX_PATH = 512,
  MAX_CONFIG_SIZE = 8192,
  WRAPBUDDY_SUFFIX_LEN = 11,
  MAX_INTERP_PHDRS = 256
};

/*
 * Build config path from /proc/self/exe
 * /path/to/binary -> /path/to/.binary.wrapbuddy
 */
static int build_config_path(char *buf, size_t bufsize) {
  int64_t path_len =
      sys_readlink("/proc/self/exe", buf, bufsize - CONFIG_HEADER_SIZE);
  if (path_len <= 0 || path_len >= (int64_t)(bufsize - CONFIG_HEADER_SIZE)) {
    return -1;
  }

  /* Find last '/' to insert '.' before filename */
  int64_t slash_pos = path_len - 1;
  while (slash_pos >= 0 && buf[slash_pos] != '/') {
    slash_pos--;
  }

  /* Move filename right by 1 to make room for '.' */
  int64_t name_start = slash_pos + 1;
  int64_t name_len = path_len - name_start;
  for (int64_t idx = name_len - 1; idx >= 0; idx--) {
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
 * Read entire config file into buffer
 */
static int read_config(const char *path, char *buf, size_t bufsize,
                       size_t *out_size) {
  int64_t file_desc = sys_open(path, O_RDONLY);
  if (file_desc < 0) {
    return -1;
  }

  size_t total = 0;
  while (total < bufsize) {
    int64_t bytes_read = sys_read(file_desc, buf + total, bufsize - total);
    if (bytes_read < 0) {
      if (-bytes_read == EINTR) {
        continue;
      }
      sys_close(file_desc);
      return -1;
    }
    if (bytes_read == 0) {
      break;
    }
    total += bytes_read;
  }

  sys_close(file_desc);
  *out_size = total;
  return 0;
}

/*
 * Restore original bytes at entry point
 */
static int restore_entry_bytes(uint64_t entry_vaddr, uint64_t l_addr,
                               const char *orig_bytes, size_t size,
                               uint64_t page_size) {
  uint64_t page_mask = ~(page_size - 1);
  uint64_t entry_runtime = l_addr + entry_vaddr;
  uint64_t page_start = entry_runtime & page_mask;
  uint64_t page_end = (entry_runtime + size + page_size - 1) & page_mask;
  size_t page_len = page_end - page_start;

  /* Make writable */
  int64_t ret = sys_mprotect(page_start, page_len, PROT_READ | PROT_WRITE);
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

/* ELF magic bytes */
enum {
  ELF_MAGIC_0 = 0x7f,
  ELF_MAGIC_1 = 'E',
  ELF_MAGIC_2 = 'L',
  ELF_MAGIC_3 = 'F'
};

/*
 * Validate ELF magic bytes
 */
static void validate_elf_magic(const Elf64_Ehdr *ehdr) {
  if (ehdr->e_ident[0] != ELF_MAGIC_0 || ehdr->e_ident[1] != ELF_MAGIC_1 ||
      ehdr->e_ident[2] != ELF_MAGIC_2 || ehdr->e_ident[3] != ELF_MAGIC_3) {
    die("not an ELF file");
  }
}

/*
 * Read program headers from ELF file
 */
static Elf64_Phdr *read_phdrs(const char *path, const Elf64_Ehdr *ehdr,
                              size_t *out_phdr_bytes) {
  int phnum = ehdr->e_phnum;
  if (phnum == 0) {
    die("interpreter has no program headers");
  }
  if (phnum > MAX_INTERP_PHDRS) {
    die("interpreter has too many program headers");
  }

  size_t phdr_bytes = phnum * sizeof(Elf64_Phdr);
  Elf64_Phdr *phdrs =
      (Elf64_Phdr *)sys_mmap(0, phdr_bytes, PROT_READ | PROT_WRITE,
                             MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((int64_t)phdrs < 0) {
    die("cannot allocate program headers");
  }

  int64_t file_desc = sys_open(path, O_RDONLY);
  if (file_desc < 0) {
    die("cannot open interpreter for phdrs");
  }
  if (sys_lseek(file_desc, ehdr->e_phoff, SEEK_SET) < 0) {
    die("cannot seek to program headers");
  }
  if (sys_read(file_desc, phdrs, phdr_bytes) != (ssize_t)phdr_bytes) {
    die("cannot read program headers");
  }
  sys_close(file_desc);

  *out_phdr_bytes = phdr_bytes;
  return phdrs;
}

/*
 * Find PT_LOAD range and return total size needed
 */
static size_t find_load_range(const Elf64_Phdr *phdrs, int phnum,
                              uint64_t page_size, uint64_t *out_min_vaddr) {
  uint64_t page_mask = ~(page_size - 1);
  uint64_t min_vaddr = ~0ULL;
  uint64_t max_vaddr = 0;

  for (int idx = 0; idx < phnum; idx++) {
    if (phdrs[idx].p_type != PT_LOAD) {
      continue;
    }
    if (phdrs[idx].p_vaddr < min_vaddr) {
      min_vaddr = phdrs[idx].p_vaddr;
    }
    uint64_t end = phdrs[idx].p_vaddr + phdrs[idx].p_memsz;
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
 * Convert ELF p_flags to mprotect flags
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
 * Load a single PT_LOAD segment
 */
static void load_segment(const char *path, const Elf64_Phdr *phdr,
                         uint64_t load_bias, uint64_t page_size) {
  uint64_t page_mask = ~(page_size - 1);
  uint64_t vaddr = phdr->p_vaddr + load_bias;

  int64_t file_desc = sys_open(path, O_RDONLY);
  if (file_desc < 0) {
    die("cannot open interpreter for segment");
  }
  if (sys_lseek(file_desc, phdr->p_offset, SEEK_SET) < 0) {
    die("cannot seek to segment");
  }

  /* Read segment data */
  char *dest = (char *)vaddr;
  size_t remaining = phdr->p_filesz;
  while (remaining > 0) {
    ssize_t bytes_read = sys_read(file_desc, dest, remaining);
    if (bytes_read < 0) {
      if (-bytes_read == EINTR) {
        continue;
      }
      die("read error loading interpreter");
    }
    if (bytes_read == 0) {
      die("unexpected EOF loading interpreter");
    }
    dest += bytes_read;
    remaining -= bytes_read;
  }
  sys_close(file_desc);

  /* Zero BSS */
  if (phdr->p_memsz > phdr->p_filesz) {
    my_memset((char *)vaddr + phdr->p_filesz, 0,
              phdr->p_memsz - phdr->p_filesz);
  }

  /* Set proper protections */
  uint64_t aligned = vaddr & page_mask;
  size_t maplen =
      ((vaddr - aligned) + phdr->p_memsz + page_size - 1) & page_mask;
  if (sys_mprotect(aligned, maplen, prot_from_pflags(phdr->p_flags)) < 0) {
    die("mprotect failed for interpreter segment");
  }
}

/*
 * Load ELF interpreter into memory
 *
 * Note: Error paths call die() which exits immediately. Open fds are
 * intentionally not closed before die() - the kernel cleans up on exit.
 */
static void *load_interp(const char *path, void **out_base,
                         uint64_t page_size) {
  int64_t file_desc = sys_open(path, O_RDONLY);
  if (file_desc < 0) {
    die("cannot open interpreter");
  }

  Elf64_Ehdr ehdr;
  my_memset(&ehdr, 0, sizeof(ehdr));
  if (sys_read(file_desc, &ehdr, sizeof(ehdr)) != sizeof(ehdr)) {
    die("cannot read ELF header");
  }
  sys_close(file_desc);

  validate_elf_magic(&ehdr);

  size_t phdr_bytes;
  Elf64_Phdr *phdrs = read_phdrs(path, &ehdr, &phdr_bytes);

  uint64_t min_vaddr;
  size_t total_size =
      find_load_range(phdrs, ehdr.e_phnum, page_size, &min_vaddr);

  void *base = (void *)sys_mmap(0, total_size, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((int64_t)base < 0) {
    die("mmap failed");
  }

  uint64_t load_bias = (uint64_t)base - min_vaddr;

  for (int idx = 0; idx < ehdr.e_phnum; idx++) {
    if (phdrs[idx].p_type == PT_LOAD) {
      load_segment(path, &phdrs[idx], load_bias, page_size);
    }
  }

  sys_munmap(phdrs, phdr_bytes);

  *out_base = base;
  return (void *)(ehdr.e_entry + load_bias);
}

/*
 * Find PT_DYNAMIC program header and return pointer to .dynamic section
 */
static Elf64_Dyn *find_dynamic_section(Elf64_Phdr *phdr, uint64_t phnum,
                                       uint64_t l_addr) {
  for (uint64_t idx = 0; idx < phnum; idx++) {
    if (phdr[idx].p_type == PT_DYNAMIC) {
      return (Elf64_Dyn *)(l_addr + phdr[idx].p_vaddr);
    }
  }
  return NULL;
}

/*
 * Find a dynamic entry by tag
 */
static Elf64_Dyn *find_dyn_entry(Elf64_Dyn *dyn, int64_t tag) {
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
static size_t count_dyn_entries(Elf64_Dyn *dyn) {
  size_t count = 0;
  while (dyn[count].d_tag != DT_NULL) {
    count++;
  }
  return count + 1; /* Include DT_NULL */
}

/*
 * Set up RPATH by creating a new .dynamic section with DT_RUNPATH
 *
 * Strategy: DT_RUNPATH's d_val is an offset from DT_STRTAB.
 * We allocate our rpath string anywhere in memory and compute:
 *   d_val = our_string_addr - (DT_STRTAB + l_addr)
 * The dynamic linker adjusts DT_STRTAB by l_addr, then computes:
 *   (DT_STRTAB + l_addr) + d_val = our_string_addr
 */
static Elf64_Dyn *setup_rpath(Elf64_Dyn *orig_dyn, const char *rpath,
                              uint64_t l_addr, size_t *out_dyn_count) {
  /* Find DT_STRTAB - we need it to compute the offset */
  Elf64_Dyn *strtab_entry = find_dyn_entry(orig_dyn, DT_STRTAB);
  if (!strtab_entry) {
    die("no DT_STRTAB found");
  }

  /* DT_STRTAB is a file vaddr; ld.so will add l_addr to get runtime addr */
  uint64_t strtab_runtime = strtab_entry->d_un.d_ptr + l_addr;

  /* Count original entries and check if DT_RUNPATH exists */
  size_t orig_count = count_dyn_entries(orig_dyn);
  Elf64_Dyn *runpath_entry = find_dyn_entry(orig_dyn, DT_RUNPATH);
  size_t new_count = runpath_entry ? orig_count : orig_count + 1;

  /* Allocate memory for: new .dynamic + rpath string */
  size_t rpath_len = my_strlen(rpath) + 1;
  size_t dyn_size = new_count * sizeof(Elf64_Dyn);
  size_t alloc_size = dyn_size + rpath_len;

  char *alloc = (char *)sys_mmap(0, alloc_size, PROT_READ | PROT_WRITE,
                                 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((int64_t)alloc < 0) {
    die("dynamic mmap failed");
  }

  Elf64_Dyn *new_dyn = (Elf64_Dyn *)alloc;
  char *rpath_str = alloc + dyn_size;

  /* Copy rpath string */
  my_memcpy(rpath_str, rpath, rpath_len);

  /* Compute offset relative to where ld.so will think strtab is */
  uint64_t rpath_offset = (uint64_t)rpath_str - strtab_runtime;

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

static void auxv_set(Elf64_auxv_t *auxv, uint64_t type, uint64_t value) {
  for (; auxv->a_type != AT_NULL; auxv++) {
    if (auxv->a_type == type) {
      auxv->a_un.a_val = value;
      return;
    }
  }
}

static uint64_t auxv_get(Elf64_auxv_t *auxv, uint64_t type) {
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
__attribute__((noreturn)) void loader_main(int64_t *stack_ptr) {
  /* Read config file */
  char config_path[MAX_PATH];
  if (build_config_path(config_path, sizeof(config_path)) < 0) {
    die("cannot build config path");
  }

  char config_buf[MAX_CONFIG_SIZE];
  size_t config_size;
  if (read_config(config_path, config_buf, sizeof(config_buf), &config_size) <
      0) {
    die("cannot read config");
  }

  if (config_size < CONFIG_HEADER_SIZE) {
    die("config too small");
  }

  /* Parse config header */
  struct Config *cfg = (struct Config *)config_buf;

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
  char *interp_path = config_buf + CONFIG_HEADER_SIZE;
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
  int64_t argc = stack_ptr[0];
  char **envp = (char **)(stack_ptr + 1 + argc + 1);

  char **env_ptr = envp;
  while (*env_ptr) {
    env_ptr++;
  }
  Elf64_auxv_t *auxv = (Elf64_auxv_t *)(env_ptr + 1);

  /* Get page size from auxv */
  uint64_t page_size = auxv_get(auxv, AT_PAGESZ);
  if (page_size == 0) {
    die("no AT_PAGESZ in auxv");
  }

  /* Calculate runtime load address (l_addr) */
  Elf64_Phdr *orig_phdr = (Elf64_Phdr *)auxv_get(auxv, AT_PHDR);
  uint64_t orig_phnum = auxv_get(auxv, AT_PHNUM);

  if (!orig_phdr || orig_phnum == 0) {
    die("no AT_PHDR or AT_PHNUM in auxv");
  }

  uint64_t l_addr = 0;
  int found_phdr = 0;
  for (uint64_t idx = 0; idx < orig_phnum; idx++) {
    if (orig_phdr[idx].p_type == PT_PHDR) {
      l_addr = (uint64_t)orig_phdr - orig_phdr[idx].p_vaddr;
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
  Elf64_Dyn *orig_dyn = find_dynamic_section(orig_phdr, orig_phnum, l_addr);
  if (!orig_dyn) {
    die("no PT_DYNAMIC found");
  }

  size_t new_dyn_count;
  Elf64_Dyn *new_dyn = setup_rpath(orig_dyn, rpath, l_addr, &new_dyn_count);

  /* Load interpreter */
  void *interp_base = NULL;
  void *interp_entry = load_interp(interp_path, &interp_base, page_size);

  /* Calculate real entry point */
  uint64_t real_entry = l_addr + cfg->orig_entry;

  /* Build new program headers with PT_INTERP and updated PT_DYNAMIC
   * Note: This allocation must remain mapped - it's referenced via auxv
   * (AT_PHDR) throughout the process lifetime. */
  size_t interp_len = my_strlen(interp_path) + 1;
  size_t alloc_size = ((orig_phnum + 1) * sizeof(Elf64_Phdr)) + interp_len;
  char *alloc = (char *)sys_mmap(0, alloc_size, PROT_READ | PROT_WRITE,
                                 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if ((int64_t)alloc < 0) {
    die("phdr mmap failed");
  }

  Elf64_Phdr *new_phdr = (Elf64_Phdr *)alloc;
  char *interp_str = alloc + ((orig_phnum + 1) * sizeof(Elf64_Phdr));

  my_memcpy(new_phdr, orig_phdr, orig_phnum * sizeof(Elf64_Phdr));
  my_memcpy(interp_str, interp_path, interp_len);

  /* Update PT_PHDR and PT_DYNAMIC to point to new locations */
  for (uint64_t idx = 0; idx < orig_phnum; idx++) {
    if (new_phdr[idx].p_type == PT_PHDR) {
      new_phdr[idx].p_vaddr = (uint64_t)new_phdr - l_addr;
      new_phdr[idx].p_paddr = new_phdr[idx].p_vaddr;
    } else if (new_phdr[idx].p_type == PT_DYNAMIC) {
      new_phdr[idx].p_vaddr = (uint64_t)new_dyn - l_addr;
      new_phdr[idx].p_paddr = new_phdr[idx].p_vaddr;
      new_phdr[idx].p_filesz = new_dyn_count * sizeof(Elf64_Dyn);
      new_phdr[idx].p_memsz = new_phdr[idx].p_filesz;
    }
  }

  /* Add PT_INTERP */
  Elf64_Phdr *interp_phdr = &new_phdr[orig_phnum];
  interp_phdr->p_type = PT_INTERP;
  interp_phdr->p_flags = PF_R;
  interp_phdr->p_offset = 0;
  interp_phdr->p_vaddr = (uint64_t)interp_str - l_addr;
  interp_phdr->p_paddr = interp_phdr->p_vaddr;
  interp_phdr->p_filesz = interp_len;
  interp_phdr->p_memsz = interp_len;
  interp_phdr->p_align = 1;

  /* Update auxv - no trampoline needed, entry goes directly to real entry */
  auxv_set(auxv, AT_BASE, (uint64_t)interp_base);
  auxv_set(auxv, AT_ENTRY, real_entry);
  auxv_set(auxv, AT_PHDR, (uint64_t)new_phdr);
  auxv_set(auxv, AT_PHNUM, orig_phnum + 1);

  /* Jump to interpreter */
  JUMP_TO_ENTRY(stack_ptr, interp_entry);
  __builtin_unreachable();
}

DEFINE_START(loader_main)
