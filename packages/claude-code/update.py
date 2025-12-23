#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for claude-code package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    extract_or_generate_lockfile,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
NPM_PACKAGE = "@anthropic-ai/claude-code"


def main() -> None:
    """Update the claude-code package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = f"https://registry.npmjs.org/{NPM_PACKAGE}/-/claude-code-{latest}.tgz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url, unpack=True)

    if not extract_or_generate_lockfile(tarball_url, SCRIPT_DIR / "package-lock.json"):
        return

    # Prepare new data with dummy hash for dependency calculation
    new_data = {
        "version": latest,
        "hash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }

    # Calculate npmDepsHash - only save if successful
    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#claude-code", "npmDepsHash", HASHES_FILE, new_data
        )
        new_data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, new_data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
