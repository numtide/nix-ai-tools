#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for claude-code package.

Claude Code provides version info at a stable endpoint and distributes
platform-specific binaries with checksums in manifest.json.
"""

import base64
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    fetch_json,
    fetch_text,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"
BASE_URL = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Platform mappings (Nix platform -> manifest platform)
PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def fetch_version() -> str:
    """Fetch the latest version from Claude Code's latest endpoint."""
    return fetch_text(f"{BASE_URL}/latest").strip()


def fetch_manifest(version: str) -> dict[str, object]:
    """Fetch the manifest.json for a specific version."""
    url = f"{BASE_URL}/{version}/manifest.json"
    result = fetch_json(url)
    if not isinstance(result, dict):
        msg = f"Expected dict from manifest.json, got {type(result)}"
        raise TypeError(msg)
    return result


def sha256_hex_to_sri(sha256_hex: str) -> str:
    """Convert a SHA256 hex hash to SRI format."""
    hash_bytes = bytes.fromhex(sha256_hex)
    b64_hash = base64.b64encode(hash_bytes).decode("ascii")
    return f"sha256-{b64_hash}"


def main() -> None:
    """Update the claude-code package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating claude-code from {current} to {latest}")

    # Fetch manifest and extract hashes
    print("Fetching manifest.json...")
    manifest = fetch_manifest(latest)

    platforms_data = manifest["platforms"]
    if not isinstance(platforms_data, dict):
        msg = "Expected 'platforms' to be a dict"
        raise TypeError(msg)

    # Convert hex checksums to SRI format
    hashes = {}
    for nix_platform, manifest_platform in PLATFORMS.items():
        platform_info = platforms_data[manifest_platform]
        if not isinstance(platform_info, dict):
            msg = f"Expected platform info to be a dict, got {type(platform_info)}"
            raise TypeError(msg)
        checksum = platform_info["checksum"]
        if not isinstance(checksum, str):
            msg = f"Expected checksum to be a str, got {type(checksum)}"
            raise TypeError(msg)
        hashes[nix_platform] = sha256_hex_to_sri(checksum)
        print(f"  {nix_platform}: {hashes[nix_platform]}")

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
