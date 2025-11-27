#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for droid package."""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_text, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "linux/x64",
    "aarch64-linux": "linux/arm64",
    "aarch64-darwin": "darwin/arm64",
}


def fetch_version() -> str:
    """Fetch the latest version from Factory AI's install script."""
    script_content = fetch_text("https://app.factory.ai/cli")
    match = re.search(r'VER="([^"]+)"', script_content)
    if not match:
        msg = "Could not extract version from install script"
        raise ValueError(msg)
    return match.group(1)


def main() -> None:
    """Update the droid package."""
    data = json.loads(HASHES_FILE.read_text())
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    droid_hashes = {}
    ripgrep_hashes = {}

    for platform, path in PLATFORMS.items():
        # Droid binary
        url = f"https://downloads.factory.ai/factory-cli/releases/{latest}/{path}/droid"
        print(f"Fetching droid hash for {platform}...")
        droid_hashes[platform] = calculate_url_hash(url)

        # Ripgrep binary (no version in URL)
        url = f"https://downloads.factory.ai/ripgrep/{path}/rg"
        print(f"Fetching ripgrep hash for {platform}...")
        ripgrep_hashes[platform] = calculate_url_hash(url)

    HASHES_FILE.write_text(
        json.dumps(
            {"version": latest, "droid": droid_hashes, "ripgrep": ripgrep_hashes},
            indent=2,
        )
        + "\n"
    )
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
