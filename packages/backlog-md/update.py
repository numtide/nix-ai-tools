#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for backlog-md package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_github_latest_release,
    nix_eval,
    save_hashes,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

HASHES_FILE = Path(__file__).parent / "hashes.json"


def main() -> None:
    """Update the backlog-md package."""
    # Get current version (backlog-md is x86_64-linux only)
    current = nix_eval(".#packages.x86_64-linux.backlog-md.version")
    latest = fetch_github_latest_release("MrLesk", "Backlog.md")

    if current == latest:
        print("backlog-md is already up-to-date!")
        return

    print(f"Updating backlog-md from {current} to {latest}")

    # Calculate source hash for fetchFromGitHub
    tag = f"v{latest}"
    url = f"https://github.com/MrLesk/Backlog.md/archive/{tag}.tar.gz"
    print("Fetching source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    # Write temporary hashes.json with dummy node_modules hash
    data = {
        "version": latest,
        "src_hash": source_hash,
        "node_modules_hash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Calculate correct node_modules hash by building (backlog-md is x86_64-linux only)
    try:
        node_modules_hash = calculate_dependency_hash(
            ".#packages.x86_64-linux.backlog-md",
            "node_modules_hash",
            HASHES_FILE,
            data,
        )
        data["node_modules_hash"] = node_modules_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
