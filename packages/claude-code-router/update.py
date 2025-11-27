#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for claude-code-router package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"
NPM_PACKAGE = "@musistudio/claude-code-router"


def main() -> None:
    """Update the claude-code-router package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = (
        f"https://registry.npmjs.org/{NPM_PACKAGE}/-/claude-code-router-{latest}.tgz"
    )

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url, unpack=True)

    save_hashes(HASHES_FILE, {"version": latest, "hash": source_hash})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
