/*
 * checked.h - Bounds-checked container access returning error values
 *
 * Provides get_at() and substr_checked() that return std::optional or empty
 * values instead of throwing exceptions or invoking undefined behavior.
 */

#pragma once

#include <cstddef>
#include <optional>
#include <span>
#include <string_view>

namespace wrap_buddy {

// Checked access for std::span - returns optional
template <typename T>
[[nodiscard]] constexpr auto get_at(std::span<T> s, size_t idx)
    -> std::optional<T> {
  if (idx >= s.size()) {
    return std::nullopt;
  }
  return s[idx];
}

// Checked subspan - returns empty span on out-of-bounds offset or count
template <typename T>
[[nodiscard]] constexpr auto subspan_checked(std::span<T> s, size_t offset,
                                             size_t count = std::dynamic_extent)
    -> std::span<T> {
  if (offset > s.size()) {
    return {};
  }
  const auto available = s.size() - offset;
  const auto actual_count =
      (count == std::dynamic_extent) ? available : std::min(count, available);
  return s.subspan(offset, actual_count);
}

// Checked substr - returns empty view on out-of-bounds
[[nodiscard]] constexpr auto substr_checked(std::string_view sv, size_t pos,
                                            size_t count = std::string_view::npos)
    -> std::string_view {
  if (pos > sv.size()) {
    return {};
  }
  return sv.substr(pos, count);
}

} // namespace wrap_buddy
