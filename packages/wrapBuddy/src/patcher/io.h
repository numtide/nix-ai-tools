/*
 * io.h - Binary I/O helpers and error handling utilities
 */

#pragma once

#include <array>
#include <cstdint>
#include <cstring>
#include <ostream>
#include <span>
#include <string_view>
#include <type_traits>

namespace wrap_buddy {

// Thread-safe alternative to strerror
constexpr size_t kErrorBufferSize = 256;

inline auto safe_strerror(int errnum,
                          std::array<char, kErrorBufferSize> &buffer)
    -> std::string_view {
#if defined(_GNU_SOURCE) && !defined(__APPLE__)
  // GNU-specific strerror_r returns char*
  return strerror_r(errnum, buffer.data(), buffer.size());
#else
  // POSIX strerror_r returns int and fills buffer
  if (strerror_r(errnum, buffer.data(), buffer.size()) == 0) {
    return buffer.data();
  }
  return "Unknown error";
#endif
}

// Fallback for std::start_lifetime_as (C++23 P2590R2)
// Use real implementation when available, otherwise emulate with
// reinterpret_cast
#if __cpp_lib_start_lifetime_as >= 202311L
using std::start_lifetime_as;
#else
template <typename T> auto start_lifetime_as(void *ptr) -> T * {
  static_assert(std::is_trivially_copyable_v<T>);
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<T *>(ptr);
}

template <typename T> auto start_lifetime_as(const void *ptr) -> const T * {
  static_assert(std::is_trivially_copyable_v<T>);
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<const T *>(ptr);
}
#endif

// Binary I/O helpers (single NOLINT point for reinterpret_cast)
template <typename T>
auto write_struct(std::ostream &out, const T &value) -> void {
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  out.write(reinterpret_cast<const char *>(&value), sizeof(value));
}

inline auto write_bytes(std::ostream &out, std::span<const uint8_t> data)
    -> void {
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  out.write(reinterpret_cast<const char *>(data.data()),
            static_cast<std::streamsize>(data.size()));
}

} // namespace wrap_buddy
