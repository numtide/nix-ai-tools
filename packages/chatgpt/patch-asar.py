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
import re
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
    asar.write_bytes(data)


if __name__ == "__main__":
    main()
