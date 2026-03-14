#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for iflow-cli package."""

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
NPM_PACKAGE = "@iflow-ai/iflow-cli"


def main() -> None:
    """Update the iflow-cli package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = f"https://registry.npmjs.org/{NPM_PACKAGE}/-/iflow-cli-{latest}.tgz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url)

    print("Extracting/generating lockfile...")
    lockfile_ok = extract_or_generate_lockfile(
        tarball_url, SCRIPT_DIR / "package-lock.json"
    )
    if not lockfile_ok:
        print("Warning: Failed to generate lockfile, continuing anyway...")

    # Update hashes.json with dummy npmDepsHash first
    data = {
        "version": latest,
        "sourceHash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Calculate npmDepsHash
    print("Calculating npm dependencies hash...")
    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#iflow-cli", "npmDepsHash", HASHES_FILE, data
        )
        data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, data)
        print(f"npmDepsHash: {npm_deps_hash}")
    except (ValueError, NixCommandError) as e:
        print(f"Error calculating npmDepsHash: {e}")
        print("You may need to manually update the npmDepsHash")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
