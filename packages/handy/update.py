#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for handy package."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_github_latest_release, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "Handy_{version}_amd64.deb",
    "x86_64-darwin": "Handy_x64.app.tar.gz",
    "aarch64-darwin": "Handy_aarch64.app.tar.gz",
}


def main() -> None:
    """Update the handy package."""
    data = json.loads(HASHES_FILE.read_text())
    current = data["version"]
    latest = fetch_github_latest_release("cjpais", "Handy")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    base_url = f"https://github.com/cjpais/Handy/releases/download/v{latest}"
    hashes = {}
    for platform, filename in PLATFORMS.items():
        url = f"{base_url}/{filename.format(version=latest)}"
        print(f"Fetching hash for {platform}...")
        hashes[platform] = calculate_url_hash(url)

    HASHES_FILE.write_text(
        json.dumps({"version": latest, "hashes": hashes}, indent=2) + "\n"
    )
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
