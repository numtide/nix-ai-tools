/*
 * mapped_memory.h - RAII wrappers for file descriptors and memory mapping
 */

#pragma once

#include "io.h"

#include <cstdint>
#include <expected>
#include <fcntl.h>
#include <filesystem>
#include <format>
#include <span>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

namespace wrap_buddy {

namespace fs = std::filesystem;

// RAII wrapper for file descriptor (avoids manual close)
class FileDescriptor {
public:
  explicit FileDescriptor(int file_fd) : fd_(file_fd) {}
  ~FileDescriptor() {
    if (fd_ >= 0) {
      ::close(fd_);
    }
  }

  FileDescriptor(FileDescriptor &&other) noexcept : fd_(other.fd_) {
    other.fd_ = -1;
  }

  auto operator=(FileDescriptor &&other) noexcept -> FileDescriptor & {
    if (this != &other) {
      if (fd_ >= 0) {
        ::close(fd_);
      }
      fd_ = other.fd_;
      other.fd_ = -1;
    }
    return *this;
  }

  FileDescriptor(const FileDescriptor &) = delete;
  auto operator=(const FileDescriptor &) -> FileDescriptor & = delete;

  [[nodiscard]] auto get() const -> int { return fd_; }
  [[nodiscard]] auto valid() const -> bool { return fd_ >= 0; }

private:
  int fd_;
};

// RAII wrapper for mmap'd memory (avoids const_cast in munmap)
class MappedMemory {
public:
  MappedMemory(void *ptr, size_t size) : ptr_(ptr), size_(size) {}
  ~MappedMemory() {
    if (ptr_ != nullptr) {
      munmap(ptr_, size_);
    }
  }

  MappedMemory(MappedMemory &&other) noexcept
      : ptr_(other.ptr_), size_(other.size_) {
    other.ptr_ = nullptr;
    other.size_ = 0;
  }

  auto operator=(MappedMemory &&other) noexcept -> MappedMemory & {
    if (this != &other) {
      if (ptr_ != nullptr) {
        munmap(ptr_, size_);
      }
      ptr_ = other.ptr_;
      size_ = other.size_;
      other.ptr_ = nullptr;
      other.size_ = 0;
    }
    return *this;
  }

  MappedMemory(const MappedMemory &) = delete;
  auto operator=(const MappedMemory &) -> MappedMemory & = delete;

  // Factory for read-only mapping
  static auto open_readonly(const fs::path &path)
      -> std::expected<MappedMemory, std::string> {
    return open_impl(path, false);
  }

  // Factory for read-write mapping (in-place file modification)
  static auto open_readwrite(const fs::path &path)
      -> std::expected<MappedMemory, std::string> {
    return open_impl(path, true);
  }

  [[nodiscard]] auto data() const -> std::span<const uint8_t> {
    return {static_cast<const uint8_t *>(ptr_), size_};
  }

  [[nodiscard]] auto mutable_data() -> std::span<uint8_t> {
    return {static_cast<uint8_t *>(ptr_), size_};
  }

  [[nodiscard]] auto empty() const -> bool { return ptr_ == nullptr; }
  [[nodiscard]] auto size() const -> size_t { return size_; }

private:
  static auto open_impl(const fs::path &path, bool writable)
      -> std::expected<MappedMemory, std::string> {
    std::array<char, kErrorBufferSize> errbuf{};
    const FileDescriptor file(
        // NOLINTNEXTLINE(cppcoreguidelines-pro-type-vararg,hicpp-vararg)
        ::open(path.c_str(), (writable ? O_RDWR : O_RDONLY) | O_CLOEXEC));
    if (!file.valid()) {
      return std::unexpected(std::format("cannot open '{}': {}", path.string(),
                                         safe_strerror(errno, errbuf)));
    }

    struct stat file_stat = {};
    if (fstat(file.get(), &file_stat) < 0) {
      return std::unexpected(std::format("cannot stat '{}': {}", path.string(),
                                         safe_strerror(errno, errbuf)));
    }

    const auto size = static_cast<size_t>(file_stat.st_size);
    const int prot = writable ? (PROT_READ | PROT_WRITE) : PROT_READ;
    const int flags = writable ? MAP_SHARED : MAP_PRIVATE;
    void *mapped = mmap(nullptr, size, prot, flags, file.get(), 0);
    if (mapped == MAP_FAILED) {
      return std::unexpected(std::format("cannot mmap '{}': {}", path.string(),
                                         safe_strerror(errno, errbuf)));
    }

    return MappedMemory(mapped, size);
  }

  void *ptr_;
  size_t size_;
};

} // namespace wrap_buddy
