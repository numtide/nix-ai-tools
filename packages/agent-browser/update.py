#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for agent-browser package.

Fetches the latest version from npm registry and updates hashes.
Since v0.20.0 the project is a pure Rust CLI — no more TypeScript/pnpm deps.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    load_hashes,
    save_hashes,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError
from updater.version import fetch_npm_version, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"


def main() -> None:
    """Update the agent-browser package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version("agent-browser")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    # Calculate new src hash from GitHub
    url = f"https://github.com/vercel-labs/agent-browser/archive/refs/tags/v{latest}.tar.gz"
    print("Calculating source hash...")
    src_hash = calculate_url_hash(url, unpack=True)

    # Save with dummy cargoHash, then calculate the real one
    data = {
        "version": latest,
        "hash": src_hash,
        "cargoHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    try:
        cargo_hash = calculate_dependency_hash(
            ".#agent-browser",
            "cargoHash",
            HASHES_FILE,
            data.copy(),
        )
        print(f"cargoHash: {cargo_hash}")
    except (ValueError, NixCommandError) as e:
        print(f"Error calculating cargoHash: {e}")
        return

    # Write final hashes
    data["cargoHash"] = cargo_hash
    save_hashes(HASHES_FILE, data)

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
