/*
 * elf_file.h - Memory-mapped ELF file reader
 */

#pragma once

#include "io.h"
#include "mapped_memory.h"

#include <algorithm>
#include <cstdint>
#include <elf.h>
#include <expected>
#include <filesystem>
#include <fstream>
#include <optional>
#include <ranges>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace wrap_buddy {

namespace fs = std::filesystem;

class ElfFile {
public:
  static auto open(const fs::path &path)
      -> std::expected<ElfFile, std::string> {
    auto mem_result = MappedMemory::open_readonly(path);
    if (!mem_result) {
      return std::unexpected(mem_result.error());
    }

    auto mem = std::move(*mem_result);
    if (mem.size() < EI_NIDENT) {
      return std::unexpected(
          std::format("'{}' is too small to be an ELF file", path.string()));
    }

    const auto bytes = mem.data();
    if (bytes[EI_MAG0] != ELFMAG0 || bytes[EI_MAG1] != ELFMAG1 ||
        bytes[EI_MAG2] != ELFMAG2 || bytes[EI_MAG3] != ELFMAG3) {
      return std::unexpected(
          std::format("'{}' is not an ELF file", path.string()));
    }

    // Validate ELF header and program header table bounds
    const bool is_64bit = bytes[EI_CLASS] == ELFCLASS64;
    if (is_64bit) {
      if (mem.size() < sizeof(Elf64_Ehdr)) {
        return std::unexpected(
            std::format("'{}' is too small for ELF64 header", path.string()));
      }
      const auto *ehdr = start_lifetime_as<Elf64_Ehdr>(bytes.data());
      if (ehdr->e_phoff > mem.size()) {
        return std::unexpected(
            std::format("'{}' has invalid e_phoff", path.string()));
      }
      const auto phdr_table_size =
          static_cast<uint64_t>(ehdr->e_phnum) * sizeof(Elf64_Phdr);
      if (phdr_table_size > mem.size() - ehdr->e_phoff) {
        return std::unexpected(
            std::format("'{}' program header table extends past end of file",
                        path.string()));
      }
    } else {
      if (mem.size() < sizeof(Elf32_Ehdr)) {
        return std::unexpected(
            std::format("'{}' is too small for ELF32 header", path.string()));
      }
      const auto *ehdr = start_lifetime_as<Elf32_Ehdr>(bytes.data());
      if (ehdr->e_phoff > mem.size()) {
        return std::unexpected(
            std::format("'{}' has invalid e_phoff", path.string()));
      }
      const auto phdr_table_size =
          static_cast<uint64_t>(ehdr->e_phnum) * sizeof(Elf32_Phdr);
      if (phdr_table_size > mem.size() - ehdr->e_phoff) {
        return std::unexpected(
            std::format("'{}' program header table extends past end of file",
                        path.string()));
      }
    }

    return ElfFile(std::move(mem), path);
  }

  ElfFile(ElfFile &&) noexcept = default;
  auto operator=(ElfFile &&) noexcept -> ElfFile & = default;
  ~ElfFile() = default;

  ElfFile(const ElfFile &) = delete;
  auto operator=(const ElfFile &) -> ElfFile & = delete;

  [[nodiscard]] auto data() const -> std::span<const uint8_t> {
    return mapped_.data();
  }

  [[nodiscard]] auto elf_class() const -> uint8_t { return data()[EI_CLASS]; }
  [[nodiscard]] auto osabi() const -> uint8_t { return data()[EI_OSABI]; }
  [[nodiscard]] auto is_64bit() const -> bool {
    return elf_class() == ELFCLASS64;
  }

  [[nodiscard]] auto machine() const -> uint16_t {
    if (is_64bit()) {
      return start_lifetime_as<Elf64_Ehdr>(data().data())->e_machine;
    }
    return start_lifetime_as<Elf32_Ehdr>(data().data())->e_machine;
  }

  [[nodiscard]] auto type() const -> uint16_t {
    if (is_64bit()) {
      return start_lifetime_as<Elf64_Ehdr>(data().data())->e_type;
    }
    return start_lifetime_as<Elf32_Ehdr>(data().data())->e_type;
  }

  [[nodiscard]] auto entry() const -> uint64_t {
    if (is_64bit()) {
      return start_lifetime_as<Elf64_Ehdr>(data().data())->e_entry;
    }
    return start_lifetime_as<Elf32_Ehdr>(data().data())->e_entry;
  }

  [[nodiscard]] auto path() const -> const fs::path & { return path_; }

  // Check if this is a dynamically-linked executable
  [[nodiscard]] auto is_dynamic_executable() const -> bool {
    const auto elf_type = type();
    if (elf_type != ET_EXEC && elf_type != ET_DYN) {
      return false;
    }
    return has_interp();
  }

  // Get interpreter path (PT_INTERP)
  [[nodiscard]] auto interpreter() const -> std::optional<std::string> {
    if (is_64bit()) {
      return find_interp<Elf64_Ehdr, Elf64_Phdr>();
    }
    return find_interp<Elf32_Ehdr, Elf32_Phdr>();
  }

  // Get DT_NEEDED entries
  [[nodiscard]] auto needed() const -> std::vector<std::string> {
    if (is_64bit()) {
      return find_needed<Elf64_Ehdr, Elf64_Phdr, Elf64_Dyn>();
    }
    return find_needed<Elf32_Ehdr, Elf32_Phdr, Elf32_Dyn>();
  }

  // Get RPATH/RUNPATH entries
  [[nodiscard]] auto rpath() const -> std::vector<std::string> {
    if (is_64bit()) {
      return find_rpath<Elf64_Ehdr, Elf64_Phdr, Elf64_Dyn>();
    }
    return find_rpath<Elf32_Ehdr, Elf32_Phdr, Elf32_Dyn>();
  }

private:
  ElfFile(MappedMemory mapped, fs::path path)
      : mapped_(std::move(mapped)), path_(std::move(path)) {}

  [[nodiscard]] auto has_interp() const -> bool {
    if (is_64bit()) {
      return find_interp<Elf64_Ehdr, Elf64_Phdr>().has_value();
    }
    return find_interp<Elf32_Ehdr, Elf32_Phdr>().has_value();
  }

  template <typename Ehdr, typename Phdr>
  [[nodiscard]] auto find_interp() const -> std::optional<std::string> {
    const auto *ehdr = start_lifetime_as<Ehdr>(data().data());
    const std::span<const Phdr> phdrs(
        start_lifetime_as<Phdr>(data().subspan(ehdr->e_phoff).data()),
        ehdr->e_phnum);

    for (const auto &phdr : phdrs) {
      if (phdr.p_type == PT_INTERP) {
        // Validate segment bounds
        if (phdr.p_offset > data().size() ||
            phdr.p_filesz > data().size() - phdr.p_offset) {
          return std::nullopt;
        }
        if (phdr.p_filesz == 0) {
          return std::nullopt;
        }
        // Read string within segment bounds only
        auto segment = data().subspan(phdr.p_offset, phdr.p_filesz);
        auto nul_pos = std::ranges::find(segment, uint8_t{0});
        if (nul_pos == segment.end()) {
          // No null terminator - use full segment (common for ELF)
          // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
          return std::string(reinterpret_cast<const char *>(segment.data()),
                             segment.size());
        }
        auto len = static_cast<size_t>(nul_pos - segment.begin());
        // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
        return std::string(reinterpret_cast<const char *>(segment.data()), len);
      }
    }
    return std::nullopt;
  }

  // Helper to access Dyn union fields with single NOLINT point
  template <typename Dyn> static auto dyn_ptr(const Dyn &dyn) -> uint64_t {
    // NOLINTNEXTLINE(cppcoreguidelines-pro-type-union-access)
    return dyn.d_un.d_ptr;
  }

  template <typename Dyn> static auto dyn_val(const Dyn &dyn) -> uint64_t {
    // NOLINTNEXTLINE(cppcoreguidelines-pro-type-union-access)
    return dyn.d_un.d_val;
  }

  // Get string from string table with bounds checking
  static auto get_string_at(std::string_view strtab, size_t offset)
      -> std::string_view {
    if (offset >= strtab.size()) {
      return {};
    }
    // Find null terminator - string_view::substr does NOT stop at null
    const auto remaining = strtab.substr(offset);
    const auto null_pos = remaining.find('\0');
    if (null_pos == std::string_view::npos) {
      return remaining;
    }
    return remaining.substr(0, null_pos);
  }

  // Parsed dynamic section with string table
  template <typename Dyn> struct DynSection {
    std::span<const Dyn> entries;
    std::string_view strtab;
  };

  template <typename Ehdr, typename Phdr, typename Dyn>
  [[nodiscard]] auto get_dynamic_section() const
      -> std::optional<DynSection<Dyn>> {
    const auto *ehdr = start_lifetime_as<Ehdr>(data().data());
    const std::span<const Phdr> phdrs(
        start_lifetime_as<Phdr>(data().subspan(ehdr->e_phoff).data()),
        ehdr->e_phnum);

    // Find PT_DYNAMIC
    const auto dyn_phdr =
        std::ranges::find_if(phdrs, [](const auto &phdr) noexcept {
          return phdr.p_type == PT_DYNAMIC;
        });
    if (dyn_phdr == phdrs.end()) {
      return std::nullopt;
    }

    // Use p_filesz to bound the dynamic section iteration
    const auto max_entries = dyn_phdr->p_filesz / sizeof(Dyn);
    const std::span<const Dyn> entries(
        start_lifetime_as<Dyn>(data().subspan(dyn_phdr->p_offset).data()),
        max_entries);

    // Find DT_STRTAB and DT_STRSZ
    std::optional<uint64_t> strtab_vaddr;
    std::optional<size_t> strtab_size;
    for (const auto &dyn : entries) {
      if (dyn.d_tag == DT_NULL) {
        break;
      }
      if (dyn.d_tag == DT_STRTAB) {
        strtab_vaddr = dyn_ptr(dyn);
      } else if (dyn.d_tag == DT_STRSZ) {
        strtab_size = dyn_val(dyn);
      }
    }
    if (!strtab_vaddr || !strtab_size) {
      return std::nullopt;
    }
    const auto strtab =
        find_string_table<Ehdr, Phdr>(*strtab_vaddr, *strtab_size);
    if (!strtab) {
      return std::nullopt;
    }

    return DynSection<Dyn>{.entries = entries, .strtab = *strtab};
  }

  template <typename Ehdr, typename Phdr, typename Dyn>
  [[nodiscard]] auto find_needed() const -> std::vector<std::string> {
    std::vector<std::string> result;
    const auto dyn = get_dynamic_section<Ehdr, Phdr, Dyn>();
    if (!dyn) {
      return result;
    }

    for (const auto &entry : dyn->entries) {
      if (entry.d_tag == DT_NULL) {
        break;
      }
      if (entry.d_tag == DT_NEEDED) {
        const auto name = get_string_at(dyn->strtab, dyn_val(entry));
        if (!name.empty()) {
          result.emplace_back(name);
        }
      }
    }
    return result;
  }

  template <typename Ehdr, typename Phdr, typename Dyn>
  [[nodiscard]] auto find_rpath() const -> std::vector<std::string> {
    std::vector<std::string> result;
    const auto dyn = get_dynamic_section<Ehdr, Phdr, Dyn>();
    if (!dyn) {
      return result;
    }

    for (const auto &entry : dyn->entries) {
      if (entry.d_tag == DT_NULL) {
        break;
      }
      if (entry.d_tag == DT_RPATH || entry.d_tag == DT_RUNPATH) {
        const auto paths = get_string_at(dyn->strtab, dyn_val(entry));
        for (const auto part : std::views::split(paths, ':')) {
          const std::string_view path_view(part.begin(), part.end());
          if (!path_view.empty()) {
            result.emplace_back(path_view);
          }
        }
      }
    }
    return result;
  }

  template <typename Ehdr, typename Phdr>
  [[nodiscard]] auto find_string_table(uint64_t vaddr, size_t size) const
      -> std::optional<std::string_view> {
    const auto *ehdr = start_lifetime_as<Ehdr>(data().data());
    const std::span<const Phdr> phdrs(
        start_lifetime_as<Phdr>(data().subspan(ehdr->e_phoff).data()),
        ehdr->e_phnum);

    for (const auto &phdr : phdrs) {
      if (phdr.p_type == PT_LOAD) {
        if (vaddr >= phdr.p_vaddr && vaddr < phdr.p_vaddr + phdr.p_filesz) {
          const auto offset = phdr.p_offset + (vaddr - phdr.p_vaddr);
          return std::string_view(
              start_lifetime_as<char>(data().subspan(offset).data()), size);
        }
      }
    }
    return std::nullopt;
  }

  MappedMemory mapped_;
  fs::path path_;
};

// Utility functions for ELF files
inline auto is_elf_file(const fs::path &path) -> bool {
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    return false;
  }
  std::array<char, 4> magic{};
  file.read(magic.data(), magic.size());
  return file.gcount() == 4 && magic[0] == ELFMAG0 && magic[1] == ELFMAG1 &&
         magic[2] == ELFMAG2 && magic[3] == ELFMAG3;
}

inline auto is_shared_library(const fs::path &path) -> bool {
  const auto name = path.filename().string();
  return name.ends_with(".so") || name.contains(".so.");
}

inline auto osabi_compatible(uint8_t osabi_a, uint8_t osabi_b) -> bool {
  // ELFOSABI_SYSV (0) is compatible with everything
  return osabi_a == ELFOSABI_SYSV || osabi_b == ELFOSABI_SYSV ||
         osabi_a == osabi_b;
}

inline auto expand_origin(std::string_view rpath, const fs::path &origin)
    -> std::string {
  constexpr std::string_view kOriginMarker = "$ORIGIN";
  std::string result(rpath);
  size_t pos = 0;
  while ((pos = result.find(kOriginMarker)) != std::string::npos) {
    result.replace(pos, kOriginMarker.size(), origin.string());
  }
  return result;
}

} // namespace wrap_buddy
