#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for amp package.

Fetches the latest version from npm and downloads binary hashes from
the official GCS bucket.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    fetch_npm_version,
    fetch_text,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import hex_to_sri

HASHES_FILE = Path(__file__).parent / "hashes.json"
NPM_PACKAGE = "@sourcegraph/amp"
BINARY_PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def main() -> None:
    """Update the amp package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print("Fetching binary hashes...")
    binary_hashes: dict[str, str] = {}
    for nix_plat, amp_plat in BINARY_PLATFORMS.items():
        binary_hashes[nix_plat] = hex_to_sri(
            fetch_text(
                f"https://storage.googleapis.com/amp-public-assets-prod-0/cli/{latest}/{amp_plat}-amp.sha256"
            )
        )
        print(f"  {nix_plat}: {binary_hashes[nix_plat]}")

    data = {
        "version": latest,
        "binaryHashes": binary_hashes,
    }
    save_hashes(HASHES_FILE, data)

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
