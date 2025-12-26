/*
 * main.cc - wrap-buddy entry point
 *
 * Patches dynamically-linked ELF binaries with a stub loader that:
 * 1. Loads the external loader binary
 * 2. Restores original entry point bytes
 * 3. Sets up LD_LIBRARY_PATH and loads the correct ld.so
 *
 * This preserves /proc/self/exe (important for bun, node, etc.)
 */

#include "args.h"
#include "elf_file.h"
#include "patcher.h"
#include "resolver.h"
#include "soname_cache.h"

#include <cstdio>
#include <exception>
#include <expected>
#include <filesystem>
#include <optional>
#include <print>
#include <set>
#include <span>
#include <string>
#include <string_view>
#include <system_error>
#include <type_traits>
#include <variant>
#include <vector>

#include <wrap-buddy/checked.h>

// Built-in defaults (set via -D flags in Makefile)
#ifdef DEFAULT_INTERP
constexpr bool kHasDefaultInterp = true;
#else
#define DEFAULT_INTERP nullptr
constexpr bool kHasDefaultInterp = false;
#endif

#ifdef DEFAULT_LIBC_LIB
constexpr bool kHasDefaultLibcLib = true;
#else
#define DEFAULT_LIBC_LIB nullptr
constexpr bool kHasDefaultLibcLib = false;
#endif

namespace wrap_buddy {

namespace fs = std::filesystem;

namespace {

template <typename Callback>
auto process_path_entry(const fs::path &path, bool recursive,
                        Callback &&callback) -> void {
  auto invoke = std::forward<Callback>(callback);
  std::error_code err;
  if (!fs::exists(path, err) || err || fs::is_symlink(path, err) || err) {
    return;
  }

  if (fs::is_regular_file(path, err) && !err) {
    invoke(path);
    return;
  }

  if (!fs::is_directory(path, err) || err) {
    return;
  }

  if (recursive) {
    for (auto iter = fs::recursive_directory_iterator(path, err);
         iter != fs::recursive_directory_iterator() && !err;
         iter.increment(err)) {
      if (!iter->is_symlink(err) && !err && iter->is_regular_file(err) &&
          !err) {
        invoke(iter->path());
      }
    }
  } else {
    for (auto iter = fs::directory_iterator(path, err);
         iter != fs::directory_iterator() && !err; iter.increment(err)) {
      if (!iter->is_symlink(err) && !err && iter->is_regular_file(err) &&
          !err) {
        invoke(iter->path());
      }
    }
  }
}

auto report_errors(const std::vector<std::string> &errors,
                   const std::vector<MissingDepsError> &all_missing) -> void {
  for (const auto &err : errors) {
    std::println(stderr, "error: {}", err);
  }

  if (!all_missing.empty()) {
    std::println(stderr, "\nerror: missing dependencies");
    std::println(
        stderr,
        "       add library paths with --libs or use --ignore-missing\n");
    for (const auto &missing : all_missing) {
      std::println(stderr, "{}:", missing.binary.string());
      for (const auto &dep : missing.deps) {
        std::println(stderr, "  {}", dep);
      }
    }
  }
}

auto run_patcher(const Args &args, const InterpreterInfo &interp_info) -> int {
  // Build soname cache
  SonameCache cache;
  std::set<fs::path> discovered_lib_dirs;

  populate_cache(cache, args.paths, discovered_lib_dirs, args.recursive);
  populate_cache(cache, args.libs, discovered_lib_dirs, false);
  populate_cache(cache, args.runtime_deps, discovered_lib_dirs, false);

  const PatchConfig config{.runtime_deps = args.runtime_deps,
                           .all_lib_dirs = discovered_lib_dirs};

  std::vector<MissingDepsError> all_missing;
  std::vector<std::string> errors;

  auto process_file = [&](const fs::path &path) -> void {
    if (!is_elf_file(path)) {
      return;
    }

    auto result = process_binary(path, cache, interp_info, args.ignore_missing,
                                 config, args.dry_run);
    if (!result) {
      std::visit(
          [&](auto &&error) -> void {
            using T = std::decay_t<decltype(error)>;
            if constexpr (std::is_same_v<T, MissingDepsError>) {
              all_missing.push_back(std::forward<decltype(error)>(error));
            } else {
              errors.push_back(std::format("{}: {}", path.string(), error));
            }
          },
          result.error());
    }
  };

  for (const auto &path : args.paths) {
    process_path_entry(path, args.recursive, process_file);
  }

  report_errors(errors, all_missing);
  return (errors.empty() && all_missing.empty()) ? 0 : 1;
}

} // namespace

} // namespace wrap_buddy

auto main(int argc, char *argv[]) -> int {
  using wrap_buddy::Args;
  using wrap_buddy::get_interpreter_info;
  using wrap_buddy::get_stub;
  using wrap_buddy::HelpRequested;
  using wrap_buddy::InterpreterInfo;
  using wrap_buddy::parse_args;
  using wrap_buddy::run_patcher;
  using wrap_buddy::usage;
  namespace fs = std::filesystem;

  try {
    const std::span<char *> argv_span(argv, static_cast<size_t>(argc));
    const auto progname_ptr = wrap_buddy::get_at(argv_span, 0);
    const std::string_view progname =
        progname_ptr ? *progname_ptr : "wrap-buddy";

    auto args_result = parse_args(argv_span);
    if (!args_result) {
      return std::visit(
          [&](auto &&err) -> int {
            using T = std::decay_t<decltype(err)>;
            if constexpr (std::is_same_v<T, HelpRequested>) {
              usage(progname);
              return 0;
            } else {
              std::println(stderr, "error: {}", err);
              usage(progname);
              return 1;
            }
          },
          args_result.error());
    }
    const auto &args = *args_result;

    std::expected<InterpreterInfo, std::string> interp_result;
    if (args.interpreter) {
      interp_result = get_interpreter_info(*args.interpreter);
    } else if constexpr (kHasDefaultInterp) {
      std::optional<fs::path> libc_lib;
      if constexpr (kHasDefaultLibcLib) {
        libc_lib = DEFAULT_LIBC_LIB;
      }
      interp_result = get_interpreter_info(DEFAULT_INTERP, libc_lib);
    } else {
      std::println(
          stderr,
          "error: no interpreter specified\n"
          "       use --interpreter to specify the dynamic linker path");
      return 1;
    }

    if (!interp_result) {
      std::println(stderr, "error: {}", interp_result.error());
      return 1;
    }

    const auto &interp_info = *interp_result;
    std::println("Using interpreter: {}", interp_info.path);

    auto stub_64 = get_stub(true);
    if (!stub_64.empty()) {
      std::println("64-bit stub: {} bytes", stub_64.size());
    } else {
      std::println("64-bit stub: not available");
    }

    auto stub_32 = get_stub(false);
    if (!stub_32.empty()) {
      std::println("32-bit stub: {} bytes", stub_32.size());
    } else {
      std::println("32-bit stub: not available");
    }

    return run_patcher(args, interp_info);
  } catch (const std::exception &ex) {
    // Use fputs in catch handler - std::println can throw
    // Explicitly discard return values - nothing we can do if error output
    // fails
    static_cast<void>(std::fputs("fatal error: ", stderr));
    static_cast<void>(std::fputs(ex.what(), stderr));
    static_cast<void>(std::fputc('\n', stderr));
    return 1;
  }
}
