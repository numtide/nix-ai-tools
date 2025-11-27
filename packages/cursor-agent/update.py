#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for cursor-agent package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    fetch_version_from_text,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "linux/x64",
    "aarch64-linux": "linux/arm64",
    "x86_64-darwin": "darwin/x64",
    "aarch64-darwin": "darwin/arm64",
}

VERSION_URL = "https://cursor.com/install"
VERSION_PATTERN = r"downloads\.cursor\.com/lab/([0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]+)"


def main() -> None:
    """Update the cursor-agent package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_version_from_text(VERSION_URL, VERSION_PATTERN)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url_template = f"https://downloads.cursor.com/lab/{latest}/{{platform}}/agent-cli-package.tar.gz"
    hashes = calculate_platform_hashes(url_template, PLATFORMS)

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
