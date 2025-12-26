/*
 * soname_cache.h - Library discovery and soname caching
 */

#pragma once

#include "elf_file.h"

#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace wrap_buddy {

namespace fs = std::filesystem;

using SonameKey = std::pair<std::string, uint16_t>; // (soname, e_machine)
using SonameEntry = std::pair<fs::path, uint8_t>;   // (directory, osabi)
using SonameCache = std::map<SonameKey, std::vector<SonameEntry>>;

inline auto process_library(const fs::path &lib_path, SonameCache &cache,
                            std::set<fs::path> &lib_dirs,
                            std::vector<fs::path> &rpath_queue) -> void {
  auto elf_result = ElfFile::open(lib_path);
  if (!elf_result) {
    return;
  }

  std::error_code err;
  const auto resolved = fs::canonical(lib_path, err);
  if (err) {
    return;
  }

  auto &elf = *elf_result;
  const auto lib_dir = resolved.parent_path();

  cache[{lib_path.filename().string(), elf.machine()}].emplace_back(
      lib_dir, elf.osabi());
  lib_dirs.insert(lib_dir);

  // Queue RPATH directories for transitive scanning
  for (const auto &rpath : elf.rpath()) {
    const auto expanded = expand_origin(rpath, lib_dir);
    if (fs::exists(expanded, err) && !err) {
      rpath_queue.emplace_back(expanded);
    }
  }
}

template <typename DirIterator>
auto scan_directory(const fs::path &dir_path, SonameCache &cache,
                    std::set<fs::path> &lib_dirs, std::vector<fs::path> &queue)
    -> void {
  std::error_code err;
  for (auto iter = DirIterator(dir_path, err); iter != DirIterator() && !err;
       iter.increment(err)) {
    if (!iter->is_regular_file(err) || err) {
      continue;
    }
    const auto &path = iter->path();
    if (is_shared_library(path) && is_elf_file(path)) {
      process_library(path, cache, lib_dirs, queue);
    }
  }
}

inline auto populate_cache(SonameCache &cache,
                           const std::vector<fs::path> &paths,
                           std::set<fs::path> &lib_dirs, bool recursive)
    -> void {
  std::set<fs::path> visited;
  std::vector<fs::path> queue = paths;
  std::error_code err;

  while (!queue.empty()) {
    auto current_path = std::move(queue.back());
    queue.pop_back();

    if (!fs::exists(current_path, err) || err) {
      continue;
    }

    auto canonical_path = fs::canonical(current_path, err);
    if (err || visited.contains(canonical_path)) {
      continue;
    }
    visited.insert(canonical_path);

    if (fs::is_regular_file(current_path, err) && !err) {
      if (is_shared_library(current_path) && is_elf_file(current_path)) {
        process_library(current_path, cache, lib_dirs, queue);
      }
    } else if (fs::is_directory(current_path, err) && !err) {
      if (recursive) {
        scan_directory<fs::recursive_directory_iterator>(current_path, cache,
                                                         lib_dirs, queue);
      } else {
        scan_directory<fs::directory_iterator>(current_path, cache, lib_dirs,
                                               queue);
      }
    }
  }
}

inline auto find_dependency(const SonameCache &cache, const std::string &soname,
                            uint16_t arch, uint8_t osabi)
    -> std::optional<fs::path> {
  auto iter = cache.find({soname, arch});
  if (iter == cache.end()) {
    return std::nullopt;
  }

  for (const auto &[dir, lib_osabi] : iter->second) {
    if (osabi_compatible(osabi, lib_osabi)) {
      return dir;
    }
  }
  return std::nullopt;
}

} // namespace wrap_buddy
