/*
 * config.h - wrapBuddy config file format
 *
 * Shared between the freestanding loader and the C++ patcher tool.
 * The config file stores metadata needed to restore the original binary
 * and set up the runtime environment.
 */

#pragma once

#ifdef __cplusplus
#include <cstdint>
#else
#include "freestanding.h"
#endif

/*
 * Config file naming
 */
#define WRAPBUDDY_SUFFIX ".wrapbuddy"
#define WRAPBUDDY_SUFFIX_LEN 11

/*
 * Config file header - architecture dependent
 *
 * The config file is placed next to the binary with a dot prefix:
 *   /path/to/binary -> /path/to/.binary.wrapbuddy
 *
 * Format:
 *   [header]        - Config32 or Config64 depending on ELF class
 *   [interp_path]   - null-terminated interpreter path
 *   [rpath]         - null-terminated colon-separated library paths
 *   [orig_bytes]    - original bytes from entry point (to restore)
 *
 * 64-bit header: orig_entry(8) + stub_size(8) + interp_len(2) + rpath_len(2) = 20 bytes
 * 32-bit header: orig_entry(4) + stub_size(4) + interp_len(2) + rpath_len(2) = 12 bytes
 */

#ifdef __GNUC__
#define PACKED __attribute__((packed))
#else
#define PACKED
#endif

struct PACKED Config64 {
  uint64_t orig_entry;
  uint64_t stub_size;
  uint16_t interp_len;
  uint16_t rpath_len;
};

struct PACKED Config32 {
  uint32_t orig_entry;
  uint32_t stub_size;
  uint16_t interp_len;
  uint16_t rpath_len;
};

#define CONFIG64_HEADER_SIZE 20
#define CONFIG32_HEADER_SIZE 12

/*
 * For freestanding code: select config struct based on pointer size
 */
#ifndef __cplusplus
#if __SIZEOF_POINTER__ == 8
typedef struct Config64 Config;
#define CONFIG_HEADER_SIZE CONFIG64_HEADER_SIZE
#else
typedef struct Config32 Config;
#define CONFIG_HEADER_SIZE CONFIG32_HEADER_SIZE
#endif
#endif
