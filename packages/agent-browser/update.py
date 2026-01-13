#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for agent-browser package.

Fetches the latest version from npm registry and updates hashes.
The source is from GitHub but package-lock.json is generated from npm tarball.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    extract_or_generate_lockfile,
    load_hashes,
    save_hashes,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError
from updater.version import fetch_npm_version, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"
SCRIPT_DIR = Path(__file__).parent


def main() -> None:
    """Update the agent-browser package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version("agent-browser")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    # Extract/generate package-lock.json from npm registry
    tarball_url = (
        f"https://registry.npmjs.org/agent-browser/-/agent-browser-{latest}.tgz"
    )
    print("Extracting/generating package-lock.json...")
    if not extract_or_generate_lockfile(tarball_url, SCRIPT_DIR / "package-lock.json"):
        return

    # Calculate new src hash from GitHub
    url = f"https://github.com/vercel-labs/agent-browser/archive/refs/heads/ctate/{latest}.tar.gz"
    print("Calculating source hash...")
    src_hash = calculate_url_hash(url, unpack=True)

    # Save with dummy hashes first
    data = {
        "version": latest,
        "hash": src_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Calculate cargoHash
    try:
        cargo_hash = calculate_dependency_hash(
            ".#agent-browser", "cargoHash", HASHES_FILE, data
        )
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    # Calculate npmDepsHash
    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#agent-browser", "npmDepsHash", HASHES_FILE, data
        )
        data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
