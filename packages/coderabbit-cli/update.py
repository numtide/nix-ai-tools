#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for coderabbit-cli package."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_text, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def fetch_version() -> str:
    """Fetch the latest version from CodeRabbit's VERSION endpoint."""
    return fetch_text("https://cli.coderabbit.ai/releases/latest/VERSION").strip()


def main() -> None:
    """Update the coderabbit-cli package."""
    data = json.loads(HASHES_FILE.read_text())
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    base_url = f"https://cli.coderabbit.ai/releases/{latest}"
    hashes = {}
    for platform, suffix in PLATFORMS.items():
        url = f"{base_url}/coderabbit-{suffix}.zip"
        print(f"Fetching hash for {platform}...")
        hashes[platform] = calculate_url_hash(url)

    HASHES_FILE.write_text(
        json.dumps({"version": latest, "hashes": hashes}, indent=2) + "\n"
    )
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
