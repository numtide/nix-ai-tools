#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for kilocode-cli package.

Since v1.0.0, Kilocode CLI ships as platform-specific native binaries
via scoped npm packages (@kilocode/cli-{platform}-{arch}).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def main() -> None:
    """Update the kilocode-cli package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version("@kilocode/cli")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating kilocode-cli from {current} to {latest}")

    url_template = "https://registry.npmjs.org/@kilocode/cli-{platform}/-/cli-{platform}-{version}.tgz"
    hashes = calculate_platform_hashes(url_template, PLATFORMS, version=latest)

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
