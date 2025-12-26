/*
 * resolver.h - Dependency resolution and RPATH building
 */

#pragma once

#include "elf_file.h"
#include "patcher.h"
#include "soname_cache.h"

#include <cstdint>
#include <expected>
#include <filesystem>
#include <fnmatch.h>
#include <optional>
#include <print>
#include <set>
#include <string>
#include <variant>
#include <vector>

namespace wrap_buddy {

namespace fs = std::filesystem;

struct InterpreterInfo {
  std::string path;
  uint16_t arch = 0; // e_machine
  uint8_t osabi = 0; // EI_OSABI
  std::optional<fs::path> libc_lib;
};

struct PatchConfig {
  std::vector<fs::path> runtime_deps;
  std::set<fs::path> all_lib_dirs;
};

// Result types for explicit control flow
enum class PatchResult : std::uint8_t { Skipped, Patched, MissingDeps };

struct MissingDepsError {
  fs::path binary;
  std::vector<std::string> deps;
};

inline auto resolve_dependency(const std::string &dep, const SonameCache &cache,
                               const std::optional<fs::path> &libc_lib,
                               const std::vector<std::string> &existing_rpath,
                               const fs::path &binary_dir, uint16_t arch,
                               uint8_t osabi) -> std::optional<fs::path> {
  std::error_code err_code;

  // Check libc lib first
  if (libc_lib && fs::exists(*libc_lib / dep, err_code) && !err_code) {
    return libc_lib;
  }

  // Check existing RPATH
  for (const auto &rpath : existing_rpath) {
    auto expanded = expand_origin(rpath, binary_dir);
    if (fs::exists(fs::path(expanded) / dep, err_code) && !err_code) {
      return expanded;
    }
  }

  // Check cache
  return find_dependency(cache, dep, arch, osabi);
}

inline auto build_rpath(const std::set<fs::path> &library_dirs,
                        const std::vector<fs::path> &runtime_deps,
                        const std::set<fs::path> &all_lib_dirs,
                        const std::optional<fs::path> &libc_lib,
                        const std::vector<std::string> &existing_rpath)
    -> std::string {
  std::set<fs::path> combined = all_lib_dirs;
  combined.insert(library_dirs.begin(), library_dirs.end());
  std::error_code err_code;

  // Preserve existing Nix store RPATH entries
  for (const auto &rpath : existing_rpath) {
    if (rpath.starts_with("/nix/store/") && fs::exists(rpath, err_code) &&
        !err_code) {
      combined.insert(rpath);
    }
  }

  // Add runtime deps
  for (const auto &dep : runtime_deps) {
    if (fs::exists(dep, err_code) && !err_code) {
      combined.insert(dep);
    }
  }

  std::string result;
  for (const auto &dir : combined) {
    if (!result.empty()) {
      result += ':';
    }
    result += dir.string();
  }

  if (libc_lib) {
    if (!result.empty()) {
      result += ':';
    }
    result += libc_lib->string();
  }

  return result;
}

// Error type that can be either a string or missing deps
using ProcessError = std::variant<std::string, MissingDepsError>;

inline auto process_binary(const fs::path &binary_path,
                           const SonameCache &cache,
                           const InterpreterInfo &interp_info,
                           const std::vector<std::string> &ignore_missing,
                           const PatchConfig &config, bool dry_run)
    -> std::expected<PatchResult, ProcessError> {

  auto elf_result = ElfFile::open(binary_path);
  if (!elf_result) {
    return std::unexpected(ProcessError{elf_result.error()});
  }

  auto &elf = *elf_result;

  // Skip non-dynamic executables
  if (!elf.is_dynamic_executable()) {
    return PatchResult::Skipped;
  }

  // Skip if already has Nix store interpreter
  auto current_interp = elf.interpreter();
  if (current_interp && current_interp->starts_with("/nix/store/")) {
    return PatchResult::Skipped;
  }

  // Skip if arch doesn't match
  if (elf.machine() != interp_info.arch) {
    return PatchResult::Skipped;
  }

  // Skip if OSABI incompatible
  if (!osabi_compatible(elf.osabi(), interp_info.osabi)) {
    return PatchResult::Skipped;
  }

  auto deps = elf.needed();
  auto existing_rpath = elf.rpath();
  auto binary_dir = binary_path.parent_path();

  std::set<fs::path> library_dirs;
  std::vector<std::string> missing;

  for (const auto &dep : deps) {
    auto lib_dir =
        resolve_dependency(dep, cache, interp_info.libc_lib, existing_rpath,
                           binary_dir, elf.machine(), elf.osabi());
    if (lib_dir) {
      library_dirs.insert(*lib_dir);
    } else {
      bool ignored = false;
      for (const auto &pattern : ignore_missing) {
        if (fnmatch(pattern.c_str(), dep.c_str(), 0) == 0) {
          ignored = true;
          break;
        }
      }
      if (!ignored) {
        missing.push_back(dep);
      }
    }
  }

  if (!missing.empty()) {
    return std::unexpected(ProcessError{
        MissingDepsError{.binary = binary_path, .deps = std::move(missing)}});
  }

  auto rpath =
      build_rpath(library_dirs, config.runtime_deps, config.all_lib_dirs,
                  interp_info.libc_lib, existing_rpath);

  std::println("Patching: {}", binary_path.string());

  auto patch_result =
      patch_binary(binary_path, interp_info.path, rpath, dry_run);
  if (!patch_result) {
    return std::unexpected(ProcessError{patch_result.error()});
  }

  std::println("Patched: {}", binary_path.string());
  return PatchResult::Patched;
}

inline auto
get_interpreter_info(const std::string &path,
                     std::optional<fs::path> libc_lib = std::nullopt)
    -> std::expected<InterpreterInfo, std::string> {
  auto elf_result = ElfFile::open(path);
  if (!elf_result) {
    return std::unexpected(elf_result.error());
  }

  return InterpreterInfo{.path = path,
                         .arch = elf_result->machine(),
                         .osabi = elf_result->osabi(),
                         .libc_lib = std::move(libc_lib)};
}

} // namespace wrap_buddy
