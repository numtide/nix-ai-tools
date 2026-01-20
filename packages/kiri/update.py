#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 -- python3

"""Update script for kiri package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"


def main() -> None:
    """Update the kiri package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release("CAPHTECH", "kiri")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating kiri from {current} to {latest}")

    # Calculate source hash from GitHub tarball
    tarball_url = f"https://github.com/CAPHTECH/kiri/archive/refs/tags/v{latest}.tar.gz"
    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url, unpack=True)

    # Prepare new data with dummy hash for dependency calculation
    new_data = {
        "version": latest,
        "hash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }

    # Calculate npmDepsHash
    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#kiri", "npmDepsHash", HASHES_FILE, new_data
        )
        new_data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, new_data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
