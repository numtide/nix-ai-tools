#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for junie.

JetBrains publishes stable releases in a jsonl manifest on the repo's main
branch; GitHub releases themselves are flooded with Nightly builds, so we
parse the manifest instead and convert its hex sha256 sums to SRI.
"""

import base64
import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import load_hashes, save_hashes, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"
MANIFEST_URL = (
    "https://raw.githubusercontent.com/JetBrains/junie/main/update-info.jsonl"
)

PLATFORM_MAP = {
    "linux-amd64": "x86_64-linux",
    "linux-aarch64": "aarch64-linux",
    "macos-amd64": "x86_64-darwin",
    "macos-aarch64": "aarch64-darwin",
}


def _hex_to_sri(hexdigest: str) -> str:
    raw = bytes.fromhex(hexdigest)
    return "sha256-" + base64.b64encode(raw).decode()


def _version_key(v: str) -> tuple[int, ...]:
    return tuple(int(p) for p in v.split("."))


def main() -> None:
    """Update junie to the latest stable version from the jsonl manifest."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]

    with urllib.request.urlopen(MANIFEST_URL) as resp:
        lines = resp.read().decode().splitlines()

    entries = [json.loads(line) for line in lines if line.strip()]

    by_version: dict[str, dict[str, str]] = {}
    for e in entries:
        nix_plat = PLATFORM_MAP.get(e["platform"])
        if nix_plat is None:
            continue
        by_version.setdefault(e["version"], {})[nix_plat] = e["sha256"]

    # Latest version covering all our platforms.
    wanted = set(PLATFORM_MAP.values())
    candidates = [v for v, p in by_version.items() if wanted <= p.keys()]
    if not candidates:
        print("No release found with all required platforms")
        return

    latest = max(candidates, key=_version_key)
    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    hashes = {plat: _hex_to_sri(h) for plat, h in by_version[latest].items()}
    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
