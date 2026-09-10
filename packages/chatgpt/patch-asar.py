#!/usr/bin/env python3
"""Apply byte-length-preserving source patches inside app.asar.

The asar header records file offsets, so every replacement is padded with
spaces to the original's exact byte length instead of re-packing the archive.
Minified identifiers change between releases, so patterns are regexes that
capture the identifiers they need instead of hard-coding them.

Patch sets are per platform: the process.report guard is absent from the
macOS build, and the writable plugin copy fix lands in whichever branch of
the copy helper runs on that platform.
"""

import argparse
import hashlib
import json
import plistlib
import re
import struct
import sys
from collections.abc import Callable
from pathlib import Path

# @parcel/watcher uses detect-libc in a named worker. Its process.report
# fallback trips a CFI guard in the bundled Owl/Electron runtime on NixOS.
# detect-libc falls back to its ELF/filesystem/ldd probes instead.
SKIP_PROCESS_REPORT = (
    re.compile(rb"isLinux\(\) && process\.report"),
    lambda _m: b"false /* nix:skip report */",
)

# The app materializes bundled plugins in ~/.codex and rewrites selected
# manifests there. The Nix store is read-only (444/555 files), so whatever
# copy helper runs - Node fs.cp on Linux, /usr/bin/ditto on macOS - preserves
# those modes in the destination, and the manifest rewrite fails. Make the
# destination writable after the copy. `exec` is the promisified execFile
# helper already used for the darwin `ditto` branch. Hoisting `platform` into
# a local buys the bytes needed to stay inside the original byte budget.
COPY_PLUGINS_WRITABLE = re.compile(
    rb"(?P<fn>async function [\w$]+\(e,t\)\{)"
    rb"if\((?P<plat>[\w$]+\.default\.platform)===`darwin`\)"
    rb"(?P<ditto>\{await (?P<exec>[\w$]+)\(`/usr/bin/ditto`,\[`--noqtn`,e,t\]\);return\})"
    rb"if\((?P=plat)!==`win32`\)\{"
    rb"await [\w$]+\.default\.cp\(e,t,\{recursive:!0,verbatimSymlinks:!0\}\);return\}"
)


def _copy_writable_linux(m: re.Match[bytes]) -> bytes:
    return (
        m["fn"]
        + b"let r="
        + m["plat"]
        + b";if(r===`darwin`)"
        + m["ditto"]
        + b"if(r!==`win32`){await "
        + m["exec"]
        + b"(`cp`,[`-r`,e+`/.`,t]);await "
        + m["exec"]
        + b"(`chmod`,[`-R`,`u+w`,t]);return}"
    )


def _copy_writable_darwin(m: re.Match[bytes]) -> bytes:
    # the chmod bytes are stolen from the non-darwin branch, which is dead on
    # macOS because the ditto branch always returns first
    return (
        m["fn"]
        + b"let r="
        + m["plat"]
        + b";if(r===`darwin`)"
        + m["ditto"][: -len(b"return}")]
        + b"await "
        + m["exec"]
        + b"(`chmod`,[`-R`,`u+w`,t]);return}"
        + b"if(r!==`win32`){await "
        + m["exec"]
        + b"(`cp`,[`-r`,e+`/.`,t]);return}"
    )


def _refresh_asar_integrity(data: bytes) -> tuple[bytes, str]:
    """Refresh per-file hashes and return data plus the ASAR header hash."""
    header_pickle_size = struct.unpack_from("<I", data, 4)[0]
    header_size = struct.unpack_from("<I", data, 12)[0]
    header_start = 16
    content_start = 8 + header_pickle_size
    raw_header = data[header_start : header_start + header_size]
    header = json.loads(raw_header)

    def refresh_files(files: dict[str, dict[str, object]]) -> None:
        for entry in files.values():
            nested = entry.get("files")
            if isinstance(nested, dict):
                refresh_files(nested)
                continue

            integrity = entry.get("integrity")
            offset = entry.get("offset")
            size = entry.get("size")
            if (
                not isinstance(integrity, dict)
                or offset is None
                or not isinstance(size, int)
            ):
                continue

            start = content_start + int(str(offset))
            content = data[start : start + size]
            block_size = integrity.get("blockSize")
            if not isinstance(block_size, int):
                sys.exit("invalid ASAR integrity block size")
            integrity["hash"] = hashlib.sha256(content).hexdigest()
            blocks = [
                hashlib.sha256(content[index : index + block_size]).hexdigest()
                for index in range(0, len(content), block_size)
            ]
            integrity["blocks"] = blocks or [hashlib.sha256(b"").hexdigest()]

    files = header.get("files")
    if not isinstance(files, dict):
        sys.exit("invalid ASAR header")
    refresh_files(files)

    encoded_header = json.dumps(header, separators=(",", ":")).encode()
    if len(encoded_header) != header_size:
        sys.exit(
            f"ASAR header size changed: expected {header_size}, got {len(encoded_header)}"
        )
    updated = data[:header_start] + encoded_header + data[header_start + header_size :]
    return updated, hashlib.sha256(encoded_header).hexdigest()


def _update_darwin_asar_integrity(asar: Path, header_hash: str) -> None:
    """Update Electron's top-level ASAR header hash in Info.plist."""
    info_plist = asar.parent.parent / "Info.plist"
    raw_plist = info_plist.read_bytes()
    plist = plistlib.loads(raw_plist)
    plist["ElectronAsarIntegrity"]["Resources/app.asar"]["hash"] = header_hash
    fmt = plistlib.FMT_BINARY if raw_plist.startswith(b"bplist") else plistlib.FMT_XML
    info_plist.write_bytes(plistlib.dumps(plist, fmt=fmt, sort_keys=False))


PATCHES: dict[
    str, list[tuple[re.Pattern[bytes], Callable[[re.Match[bytes]], bytes]]]
] = {
    "linux": [
        SKIP_PROCESS_REPORT,
        (COPY_PLUGINS_WRITABLE, _copy_writable_linux),
    ],
    "darwin": [
        (COPY_PLUGINS_WRITABLE, _copy_writable_darwin),
    ],
}


def main() -> None:
    """Patch the asar archive in place."""
    parser = argparse.ArgumentParser()
    parser.add_argument("asar", type=Path)
    parser.add_argument("platform", nargs="?", default="linux", choices=PATCHES)
    args = parser.parse_args()
    asar: Path = args.asar

    data = asar.read_bytes()
    for pattern, build in PATCHES[args.platform]:
        matches = list(pattern.finditer(data))
        if len(matches) != 1:
            sys.exit(
                f"expected 1 match for {pattern.pattern[:60]!r} in {asar}, got {len(matches)}"
            )
        m = matches[0]
        original = m.group(0)
        replacement = build(m)
        if len(replacement) > len(original):
            sys.exit(f"replacement longer than original: {replacement[:60]!r}...")
        data = (
            data[: m.start()] + replacement.ljust(len(original), b" ") + data[m.end() :]
        )
    data, header_hash = _refresh_asar_integrity(data)
    asar.write_bytes(data)
    if args.platform == "darwin":
        _update_darwin_asar_integrity(asar, header_hash)


if __name__ == "__main__":
    main()
