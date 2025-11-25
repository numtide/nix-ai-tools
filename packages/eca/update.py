#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for eca package."""

import json
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_github_latest_release,
    nix_eval,
)


def main() -> None:
    """Update the eca package."""
    script_dir = Path(__file__).parent
    script_dir / "package.nix"
    hashes_file = script_dir / "hashes.json"

    # Get current version
    current = nix_eval(".#eca.version")
    latest = fetch_github_latest_release("editor-code-assistant", "eca")

    if current == latest:
        print("eca is already up-to-date!")
        return

    print(f"Updating eca from {current} to {latest}")

    # Calculate hashes for all platforms
    platforms = [
        ("x86_64-linux", "linux-amd64"),
        ("aarch64-linux", "linux-aarch64"),
        ("x86_64-darwin", "macos-amd64"),
        ("aarch64-darwin", "macos-aarch64"),
    ]

    hashes = {"version": latest}

    for platform, url_arch in platforms:
        url = f"https://github.com/editor-code-assistant/eca/releases/download/{latest}/eca-native-{url_arch}.zip"
        print(f"Fetching hash for {platform}...")
        hashes[platform] = calculate_url_hash(url, unpack=False)

    # Also fetch hash for JAR file
    jar_url = f"https://github.com/editor-code-assistant/eca/releases/download/{latest}/eca.jar"
    print("Fetching hash for JAR...")
    hashes["jar"] = calculate_url_hash(jar_url, unpack=False)

    # Write hashes to JSON file
    hashes_file.write_text(json.dumps(hashes, indent=2) + "\n")
    print(f"Wrote hashes to {hashes_file}")

    print("Update complete for eca!")


if __name__ == "__main__":
    main()
