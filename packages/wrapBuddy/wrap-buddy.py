#!/usr/bin/env python3
"""wrap-buddy: Patch ELF binaries with a stub loader.

This approach uses a two-stage loading mechanism:
1. Small stub (~200 bytes) at entry point loads external loader
2. External loader restores original bytes, sets up LD_LIBRARY_PATH, loads ld.so

Benefits:
- Preserves /proc/self/exe (important for bun, etc.)
- Minimal space requirement at entry point
- Cleans up LD_LIBRARY_PATH for child processes
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import struct
import subprocess
import sys
import tempfile
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Iterator

from elftools.elf.dynamic import DynamicSection
from elftools.elf.elffile import ELFFile
from elftools.elf.enums import ENUM_E_MACHINE

# ELF constants
PT_NULL = 0
PT_LOAD = 1
PT_INTERP = 3
PF_X = 1
PF_W = 2
PF_R = 4
PAGE_SIZE = 4096

# ASCII printable range (for C string escaping)
ASCII_PRINTABLE_MIN = 32  # space character
ASCII_PRINTABLE_MAX = 127  # DEL character (first non-printable)

# Config file format
CONFIG_HEADER_FORMAT = "<QQHH"  # orig_entry, stub_size, interp_len, rpath_len
CONFIG_HEADER_SIZE = struct.calcsize(CONFIG_HEADER_FORMAT)

# Cache type
SonameCache = defaultdict[tuple[str, str], list[tuple[Path, str]]]


@dataclass
class InterpreterInfo:
    """Information about the dynamic linker."""

    path: str
    arch: str
    osabi: str
    libc_lib: Path | None


@dataclass
class PatchConfig:
    """Configuration for patching binaries."""

    source_dir: Path
    loader_bin_path: Path
    runtime_deps: list[Path]
    # All library directories discovered during cache population (for transitive deps)
    all_lib_dirs: set[Path]


@dataclass
class Elf64Phdr:
    """ELF64 program header."""

    p_type: int
    p_flags: int
    p_offset: int
    p_vaddr: int
    p_paddr: int
    p_filesz: int
    p_memsz: int
    p_align: int

    SIZE = 56

    @classmethod
    def unpack(cls, data: bytes) -> Elf64Phdr:
        """Unpack a program header from raw bytes."""
        (p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align) = (
            struct.unpack("<IIQQQQQQ", data[:56])
        )
        return cls(
            p_type=p_type,
            p_flags=p_flags,
            p_offset=p_offset,
            p_vaddr=p_vaddr,
            p_paddr=p_paddr,
            p_filesz=p_filesz,
            p_memsz=p_memsz,
            p_align=p_align,
        )

    def pack(self) -> bytes:
        """Pack the program header into raw bytes."""
        return struct.pack(
            "<IIQQQQQQ",
            self.p_type,
            self.p_flags,
            self.p_offset,
            self.p_vaddr,
            self.p_paddr,
            self.p_filesz,
            self.p_memsz,
            self.p_align,
        )


def is_elf_file(path: Path) -> bool:
    """Check if file is an ELF binary."""
    try:
        with path.open("rb") as f:
            return f.read(4) == b"\x7fELF"
    except (OSError, PermissionError):
        return False


def get_arch(elf: ELFFile) -> str:
    """Get machine architecture from ELF header."""
    return ENUM_E_MACHINE.get(elf.header.e_machine, elf.header.e_machine)  # type: ignore[no-any-return]


def get_osabi(elf: ELFFile) -> str:
    """Get OS/ABI from ELF header."""
    return elf.header.e_ident.EI_OSABI  # type: ignore[no-any-return]


def is_dynamic_executable(elf: ELFFile) -> bool:
    """Check if ELF is a dynamically-linked executable."""
    if elf.header.e_type not in ("ET_EXEC", "ET_DYN"):
        return False
    return any(seg.header.p_type == "PT_INTERP" for seg in elf.iter_segments())


def get_dependencies(elf: ELFFile) -> list[str]:
    """Extract DT_NEEDED entries from ELF dynamic section."""
    for section in elf.iter_sections():
        if isinstance(section, DynamicSection):
            return [tag.needed for tag in section.iter_tags("DT_NEEDED")]
    return []


def get_interpreter(elf: ELFFile) -> str | None:
    """Get the PT_INTERP (dynamic linker path) from ELF."""
    for segment in elf.iter_segments():
        if segment.header.p_type == "PT_INTERP":
            return segment.get_interp_name()  # type: ignore[no-any-return]
    return None


def get_rpath(elf: ELFFile) -> list[str]:
    """Get existing RPATH/RUNPATH from ELF."""
    rpaths = []
    for section in elf.iter_sections():
        if isinstance(section, DynamicSection):
            for tag in section.iter_tags():
                if tag.entry.d_tag in ("DT_RPATH", "DT_RUNPATH"):
                    rpaths.extend(tag.runpath.split(":"))
            break
    return [p for p in rpaths if p]


def osabi_are_compatible(osabi1: str, osabi2: str) -> bool:
    """Check if two OS ABIs are compatible."""
    if osabi1 == "ELFOSABI_SYSV" or osabi2 == "ELFOSABI_SYSV":
        return True
    return osabi1 == osabi2


def _is_shared_library(file_path: Path) -> bool:
    """Check if a file looks like a shared library by name."""
    return file_path.suffix == ".so" or ".so." in file_path.name


def _get_files_to_scan(path: Path, *, recursive: bool) -> list[Path]:
    """Get list of files to scan from a path."""
    if path.is_file():
        return [path]
    if recursive:
        return [p for p in path.rglob("*") if p.is_file()]
    return [p for p in path.iterdir() if p.is_file()]


def _expand_rpath_entries(rpath_entries: list[str], lib_dir: Path) -> list[Path]:
    """Expand RPATH entries, handling $ORIGIN."""
    result = []
    for rpath_dir in rpath_entries:
        if "$ORIGIN" in rpath_dir:
            expanded = rpath_dir.replace("$ORIGIN", str(lib_dir))
            result.append(Path(expanded))
        else:
            result.append(Path(rpath_dir))
    return result


def _process_library_file(
    file_path: Path,
    cache: SonameCache,
    discovered_lib_dirs: set[Path],
) -> list[Path]:
    """Process a single library file, returning RPATH directories to follow."""
    try:
        with file_path.open("rb") as f:
            elf = ELFFile(f)
            arch = get_arch(elf)
            osabi = get_osabi(elf)
            rpath_entries = get_rpath(elf)
            rpath_dirs = _expand_rpath_entries(rpath_entries, file_path.parent)

        resolved = file_path.resolve()
        lib_parent = resolved.parent
        cache[(file_path.name, arch)].append((lib_parent, osabi))
        discovered_lib_dirs.add(lib_parent)
    except OSError:
        return []
    else:
        return rpath_dirs


def populate_cache(
    cache: SonameCache,
    paths: list[Path],
    discovered_lib_dirs: set[Path],
    *,
    recursive: bool = True,
) -> None:
    """Populate the soname cache with libraries found in paths.

    This follows RPATH entries from libraries to find transitive dependencies,
    similar to how auto-patchelf works.

    discovered_lib_dirs is updated with all library directories found.
    """
    cached_paths: set[Path] = set()
    lib_dirs = list(paths)

    while lib_dirs:
        path = lib_dirs.pop(0)

        if not path.exists():
            continue

        resolved_path = path.resolve()
        if resolved_path in cached_paths:
            continue
        cached_paths.add(resolved_path)

        for file_path in _get_files_to_scan(path, recursive=recursive):
            if not _is_shared_library(file_path) or not is_elf_file(file_path):
                continue
            lib_dirs.extend(
                _process_library_file(file_path, cache, discovered_lib_dirs)
            )


def find_dependency(
    cache: SonameCache, soname: str, arch: str, osabi: str
) -> Path | None:
    """Find a library in the cache matching soname, arch, and compatible ABI."""
    for lib_dir, lib_osabi in cache[(soname, arch)]:
        if osabi_are_compatible(osabi, lib_osabi):
            return lib_dir
    return None


def iter_executables(paths: list[Path], *, recursive: bool = True) -> Iterator[Path]:
    """Iterate over all ELF executables in paths."""
    for path in paths:
        if not path.exists():
            continue
        if path.is_symlink():
            continue
        if path.is_file():
            if is_elf_file(path):
                yield path
        elif path.is_dir():
            items = path.rglob("*") if recursive else path.iterdir()
            for child in items:
                if child.is_symlink():
                    continue
                if child.is_file() and is_elf_file(child):
                    yield child


def get_source_dir() -> Path:
    """Get path to source files (stub.c, common.h, etc.)."""
    script_dir = Path(__file__).resolve().parent
    if script_dir.name == "bin":
        share_path = script_dir.parent / "share" / "wrap-buddy"
        if share_path.exists():
            return share_path
    return script_dir


def get_loader_path() -> Path:
    """Get path to pre-compiled loader binary."""
    # @loader_path@ is substituted at build time
    return Path("@loader_path@")


def c_escape(s: str) -> str:
    """Escape a string for use in a C double-quoted literal."""
    escape_map = {
        "\\": "\\\\",
        '"': '\\"',
        "\n": "\\n",
        "\r": "\\r",
        "\t": "\\t",
        "\0": "\\0",
        "\f": "\\f",
    }
    result = []
    for c in s:
        if c in escape_map:
            result.append(escape_map[c])
        elif ord(c) < ASCII_PRINTABLE_MIN or ord(c) >= ASCII_PRINTABLE_MAX:
            result.append(f"\\x{ord(c):02x}")
        else:
            result.append(c)
    return "".join(result)


def _get_compiler_target(cc: str) -> str:
    """Detect compiler target architecture."""
    result = subprocess.run(
        [cc, "-dumpmachine"], check=True, capture_output=True, text=True
    )
    return result.stdout.strip()


def _build_compile_command(
    cc: str,
    source_dir: Path,
    loader_path: str,
    linker_script: Path,
    stub_c: Path,
    elf_file: Path,
    *,
    is_aarch64: bool,
) -> list[str]:
    """Build the compiler command for the stub."""
    compile_cmd = [
        cc,
        "-nostdlib",
        "-fPIC",
        "-fno-stack-protector",
        "-fno-exceptions",
        "-fno-unwind-tables",
        "-fno-asynchronous-unwind-tables",
        "-fno-builtin",
        "-Os",
        f"-I{source_dir}",
        f'-DLOADER_PATH="{c_escape(loader_path)}"',
        f"-Wl,-T,{linker_script}",
        "-Wl,-e,_start",
        "-Wl,-Ttext=0",
        "-o",
        str(elf_file),
        str(stub_c),
    ]
    # aarch64: use tiny code model for truly PC-relative addressing (adr not adrp)
    if is_aarch64:
        compile_cmd.insert(1, "-mcmodel=tiny")
    return compile_cmd


def _compile_stub_elf(compile_cmd: list[str]) -> None:
    """Compile stub to ELF format."""
    result = subprocess.run(compile_cmd, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Stub compile failed: {result.stderr}", file=sys.stderr)
        msg = "Failed to compile stub"
        raise RuntimeError(msg)


def _extract_stub_binary(elf_file: Path, bin_file: Path) -> bytes:
    """Convert ELF to flat binary and return contents."""
    objcopy_cmd = [
        "objcopy",
        "-O",
        "binary",
        "--only-section=.all",
        str(elf_file),
        str(bin_file),
    ]
    result = subprocess.run(objcopy_cmd, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"objcopy failed: {result.stderr}", file=sys.stderr)
        msg = "Failed to extract binary from stub ELF"
        raise RuntimeError(msg)
    return bin_file.read_bytes()


def _validate_stub_sources(source_dir: Path) -> tuple[Path, Path, Path]:
    """Validate and return paths to stub source files."""
    stub_c = source_dir / "stub.c"
    common_h = source_dir / "common.h"
    linker_script = source_dir / "preamble.ld"

    if not stub_c.exists():
        msg = f"stub.c not found at {stub_c}"
        raise RuntimeError(msg)
    if not common_h.exists():
        msg = f"common.h not found at {common_h}"
        raise RuntimeError(msg)
    if not linker_script.exists():
        msg = f"preamble.ld not found at {linker_script}"
        raise RuntimeError(msg)

    return stub_c, common_h, linker_script


def compile_stub(
    source_dir: Path,
    loader_path: str,
) -> bytes:
    """Compile the stub as a flat binary."""
    stub_c, _, linker_script = _validate_stub_sources(source_dir)
    cc = os.environ.get("CC", "cc")

    try:
        target = _get_compiler_target(cc)
    except subprocess.CalledProcessError as e:
        msg = f"Failed to detect compiler target: {cc} -dumpmachine failed: {e}"
        raise RuntimeError(msg) from e

    is_aarch64 = target.startswith("aarch64")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        elf_file = tmpdir_path / "stub.elf"
        bin_file = tmpdir_path / "stub.bin"

        compile_cmd = _build_compile_command(
            cc,
            source_dir,
            loader_path,
            linker_script,
            stub_c,
            elf_file,
            is_aarch64=is_aarch64,
        )
        _compile_stub_elf(compile_cmd)
        return _extract_stub_binary(elf_file, bin_file)


def find_interp_phdr_offset(data: bytes) -> int | None:
    """Find offset of PT_INTERP program header."""
    e_phoff = struct.unpack("<Q", data[32:40])[0]
    e_phnum = struct.unpack("<H", data[56:58])[0]
    e_phentsize = struct.unpack("<H", data[54:56])[0]

    for i in range(e_phnum):
        offset: int = e_phoff + i * e_phentsize
        p_type = struct.unpack("<I", data[offset : offset + 4])[0]
        if p_type == PT_INTERP:
            return offset
    return None


def find_entry_segment_info(data: bytes, entry_vaddr: int) -> tuple[int, int] | None:
    """Find file offset and available space at entry point.

    Returns (file_offset, available_bytes) or None.
    """
    e_phoff = struct.unpack("<Q", data[32:40])[0]
    e_phnum = struct.unpack("<H", data[56:58])[0]

    for i in range(e_phnum):
        offset = e_phoff + i * 56
        phdr = Elf64Phdr.unpack(data[offset : offset + 56])
        if (
            phdr.p_type == PT_LOAD
            and phdr.p_vaddr <= entry_vaddr < phdr.p_vaddr + phdr.p_filesz
        ):
            file_offset = phdr.p_offset + (entry_vaddr - phdr.p_vaddr)
            available = phdr.p_filesz - (entry_vaddr - phdr.p_vaddr)
            return file_offset, available
    return None


def write_config_file(
    config_path: Path,
    orig_entry: int,
    stub_size: int,
    interp_path: str,
    rpath: str,
    orig_bytes: bytes,
) -> None:
    """Write the config file for the loader."""
    interp_bytes = interp_path.encode() + b"\x00"
    rpath_bytes = rpath.encode() + b"\x00"

    header = struct.pack(
        CONFIG_HEADER_FORMAT,
        orig_entry,
        stub_size,
        len(interp_bytes),
        len(rpath_bytes),
    )

    config_path.write_bytes(header + interp_bytes + rpath_bytes + orig_bytes)


def patch_binary(
    binary_path: Path,
    interp_path: str,
    rpath: str,
    source_dir: Path,
    loader_bin_path: Path,
    *,
    dry_run: bool = False,
) -> bool:
    """Patch a binary with the stub loader.

    This approach:
    1. Compiles stub with path to loader
    2. Saves original entry bytes + config to .wrapbuddy file
    3. Overwrites entry point with stub
    4. Converts PT_INTERP to PT_NULL

    Returns True if successful.
    """
    data = bytearray(binary_path.read_bytes())

    # Get original entry point
    orig_entry = struct.unpack("<Q", data[24:32])[0]

    # Find file offset and available space at entry point
    segment_info = find_entry_segment_info(bytes(data), orig_entry)
    if segment_info is None:
        print("  ERROR: Cannot find entry point in PT_LOAD segment", file=sys.stderr)
        return False

    entry_file_offset, available_space = segment_info

    print(f"  Original entry: {orig_entry:#x} (file offset: {entry_file_offset:#x})")
    print(f"  Available space at entry: {available_space} bytes")
    print(f"  Loader: {loader_bin_path}")

    if dry_run:
        print("  [dry-run] Would patch binary")
        return True

    # Compile stub with loader path
    try:
        stub_code = compile_stub(source_dir, str(loader_bin_path))
    except RuntimeError as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return False

    stub_size = len(stub_code)
    print(f"  Stub compiled size: {stub_size} bytes")

    if stub_size > available_space:
        print(
            f"  ERROR: Stub ({stub_size} bytes) exceeds available space "
            f"({available_space} bytes) in code segment",
            file=sys.stderr,
        )
        return False

    # Round up stub size for alignment
    padded_size = (stub_size + 15) & ~15

    # Save original bytes
    original_bytes = bytes(data[entry_file_offset : entry_file_offset + padded_size])

    # Write config file
    config_path = binary_path.parent / f".{binary_path.name}.wrapbuddy"
    write_config_file(
        config_path,
        orig_entry,
        padded_size,
        interp_path,
        rpath,
        original_bytes,
    )
    config_path.chmod(0o644)
    print(f"  Wrote config to {config_path}")

    # Pad stub to aligned size
    stub_padded = stub_code + b"\x00" * (padded_size - len(stub_code))

    # Overwrite entry point with stub
    data[entry_file_offset : entry_file_offset + padded_size] = stub_padded
    print(f"  Overwrote {padded_size} bytes at entry point")

    # Convert PT_INTERP to PT_NULL
    interp_offset = find_interp_phdr_offset(bytes(data))
    if interp_offset is not None:
        struct.pack_into("<I", data, interp_offset, PT_NULL)
        print("  Converted PT_INTERP to PT_NULL")

    # Write patched binary
    binary_path.write_bytes(bytes(data))
    binary_path.chmod(0o755)

    return True


def expand_origin(rpath_dir: str, binary_dir: Path) -> Path | None:
    """Expand $ORIGIN in rpath to the binary's directory."""
    if "$ORIGIN" in rpath_dir:
        expanded = rpath_dir.replace("$ORIGIN", str(binary_dir))
        return Path(expanded)
    return Path(rpath_dir)


def _resolve_dependency(
    dep: str,
    cache: SonameCache,
    libc_lib: Path | None,
    existing_rpath: list[str],
    binary_dir: Path,
    file_arch: str,
    file_osabi: str,
) -> Path | None:
    """Resolve a single dependency to its library directory."""
    if libc_lib and (libc_lib / dep).exists():
        return libc_lib
    for rpath_dir in existing_rpath:
        rpath_path = expand_origin(rpath_dir, binary_dir)
        if rpath_path and (rpath_path / dep).exists():
            return rpath_path
    return find_dependency(cache, dep, file_arch, file_osabi)


def _should_skip_binary(elf: ELFFile, interp_info: InterpreterInfo) -> bool:
    """Check if a binary should be skipped."""
    if not is_dynamic_executable(elf):
        return True
    current_interp = get_interpreter(elf)
    if current_interp and current_interp.startswith("/nix/store/"):
        return True
    file_arch = get_arch(elf)
    if file_arch != interp_info.arch:
        return True
    file_osabi = get_osabi(elf)
    return not osabi_are_compatible(interp_info.osabi, file_osabi)


def _build_rpath(
    library_dirs: set[Path],
    runtime_deps: list[Path],
    all_lib_dirs: set[Path],
    libc_lib: Path | None,
) -> str:
    """Build RPATH from library directories and runtime dependencies.

    Includes all transitive library directories discovered during cache population.
    """
    # Start with all discovered library directories (includes transitive deps)
    combined_dirs = set(all_lib_dirs)

    # Add directories where direct dependencies were found
    combined_dirs.update(library_dirs)

    # Add runtime dependencies unconditionally (for dlopen'd libraries)
    for runtime_dep in runtime_deps:
        if runtime_dep.exists():
            combined_dirs.add(runtime_dep)

    # Build RPATH (colon-separated paths)
    rpath = ":".join(str(d) for d in combined_dirs)
    if libc_lib:
        if rpath:
            rpath += f":{libc_lib}"
        else:
            rpath = str(libc_lib)
    return rpath


def process_binary(
    binary_path: Path,
    cache: SonameCache,
    interp_info: InterpreterInfo,
    ignore_missing: list[str],
    patch_config: PatchConfig,
    *,
    dry_run: bool = False,
) -> tuple[bool, list[str]]:
    """Analyze and patch a binary.

    Returns (success, missing_deps).
    """
    try:
        with binary_path.open("rb") as f:
            elf = ELFFile(f)
            if _should_skip_binary(elf, interp_info):
                return True, []
            file_arch = get_arch(elf)
            file_osabi = get_osabi(elf)
            deps = get_dependencies(elf)
            existing_rpath = get_rpath(elf)
    except OSError as e:
        print(f"Error reading {binary_path}: {e}", file=sys.stderr)
        return False, []

    library_dirs: set[Path] = set()
    missing_deps: list[str] = []
    binary_dir = binary_path.parent

    for dep in deps:
        lib_dir = _resolve_dependency(
            dep,
            cache,
            interp_info.libc_lib,
            existing_rpath,
            binary_dir,
            file_arch,
            file_osabi,
        )
        if lib_dir:
            library_dirs.add(lib_dir)
        elif not any(fnmatch.fnmatch(dep, pattern) for pattern in ignore_missing):
            missing_deps.append(dep)

    if missing_deps:
        return False, missing_deps

    rpath = _build_rpath(
        library_dirs,
        patch_config.runtime_deps,
        patch_config.all_lib_dirs,
        interp_info.libc_lib,
    )

    print(f"Patching: {binary_path}")

    success = patch_binary(
        binary_path,
        interp_info.path,
        rpath,
        patch_config.source_dir,
        patch_config.loader_bin_path,
        dry_run=dry_run,
    )

    if success:
        print(f"Patched: {binary_path}")

    return success, []


def get_interpreter_info(bintools_path: Path) -> InterpreterInfo:
    """Get interpreter info from NIX_BINTOOLS nix-support directory."""
    nix_support = bintools_path / "nix-support"

    dynamic_linker_file = nix_support / "dynamic-linker"
    if not dynamic_linker_file.exists():
        msg = f"Missing {dynamic_linker_file}"
        raise ValueError(msg)

    interpreter = dynamic_linker_file.read_text().strip()

    libc_lib = None
    orig_libc_file = nix_support / "orig-libc"
    if orig_libc_file.exists():
        libc_path = Path(orig_libc_file.read_text().strip())
        libc_lib = libc_path / "lib"

    with Path(interpreter).open("rb") as f:
        elf = ELFFile(f)
        arch = get_arch(elf)
        osabi = get_osabi(elf)

    return InterpreterInfo(path=interpreter, arch=arch, osabi=osabi, libc_lib=libc_lib)


def main() -> int:
    """Run the wrap-buddy tool."""
    parser = argparse.ArgumentParser(description="Patch ELF binaries with stub loader")
    parser.add_argument(
        "--paths",
        nargs="+",
        type=Path,
        required=True,
        help="Paths to scan for executables",
    )
    parser.add_argument(
        "--libs",
        nargs="*",
        type=Path,
        default=[],
        help="Library directories to search",
    )
    parser.add_argument(
        "--runtime-dependencies",
        nargs="*",
        type=Path,
        default=[],
        help="Runtime dependency paths",
    )
    parser.add_argument(
        "--ignore-missing",
        nargs="*",
        default=[],
        help="Patterns for dependencies to ignore if missing",
    )
    parser.add_argument(
        "--no-recurse",
        action="store_true",
        help="Don't recurse into subdirectories",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes",
    )
    parser.add_argument(
        "--interpreter",
        type=str,
        help="Path to dynamic linker (default: from NIX_BINTOOLS)",
    )
    args = parser.parse_args()

    bintools = os.environ.get("NIX_BINTOOLS")
    if args.interpreter:
        with Path(args.interpreter).open("rb") as f:
            elf = ELFFile(f)
            interp_info = InterpreterInfo(
                path=args.interpreter,
                arch=get_arch(elf),
                osabi=get_osabi(elf),
                libc_lib=None,
            )
    elif bintools:
        interp_info = get_interpreter_info(Path(bintools))
    else:
        print(
            "Error: NIX_BINTOOLS not set and --interpreter not provided",
            file=sys.stderr,
        )
        return 1

    print(f"Using interpreter: {interp_info.path}")

    source_dir = get_source_dir()
    loader_bin_path = get_loader_path()

    if not loader_bin_path.exists():
        print(f"Error: loader.bin not found at {loader_bin_path}", file=sys.stderr)
        return 1

    print(f"Using loader: {loader_bin_path}")

    cache: SonameCache = defaultdict(list)
    discovered_lib_dirs: set[Path] = set()
    populate_cache(
        cache, args.paths, discovered_lib_dirs, recursive=not args.no_recurse
    )
    populate_cache(cache, args.libs, discovered_lib_dirs, recursive=False)
    populate_cache(
        cache, args.runtime_dependencies, discovered_lib_dirs, recursive=False
    )

    recursive = not args.no_recurse
    all_missing: dict[Path, list[str]] = {}
    success = True

    patch_config = PatchConfig(
        source_dir=source_dir,
        loader_bin_path=loader_bin_path,
        runtime_deps=args.runtime_dependencies,
        all_lib_dirs=discovered_lib_dirs,
    )

    for binary in iter_executables(args.paths, recursive=recursive):
        ok, missing = process_binary(
            binary,
            cache,
            interp_info,
            args.ignore_missing,
            patch_config,
            dry_run=args.dry_run,
        )
        if not ok:
            success = False
            if missing:
                all_missing[binary] = missing

    if all_missing:
        print("\nMissing dependencies:", file=sys.stderr)
        for binary, deps in all_missing.items():
            print(f"  {binary}:", file=sys.stderr)
            for dep in deps:
                print(f"    - {dep}", file=sys.stderr)
        return 1

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
