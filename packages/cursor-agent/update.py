#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for cursor-agent package."""

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
    "x86_64-darwin": "darwin/x64",
    "aarch64-darwin": "darwin/arm64",
}


def fetch_version() -> str:
    """Fetch the latest version by scraping the install script."""
    install_script = fetch_text("https://cursor.com/install")
    match = re.search(
        r"downloads\.cursor\.com/lab/([0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]+)",
        install_script,
    )
    if not match:
        msg = "Could not extract version from install script"
        raise ValueError(msg)
    return match.group(1)


def main() -> None:
    """Update the cursor-agent package."""
    data = json.loads(HASHES_FILE.read_text())
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    base_url = f"https://downloads.cursor.com/lab/{latest}"
    hashes = {}
    for platform, path in PLATFORMS.items():
        url = f"{base_url}/{path}/agent-cli-package.tar.gz"
        print(f"Fetching hash for {platform}...")
        hashes[platform] = calculate_url_hash(url)

    HASHES_FILE.write_text(
        json.dumps({"version": latest, "hashes": hashes}, indent=2) + "\n"
    )
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
