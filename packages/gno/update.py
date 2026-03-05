#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#bun nixpkgs#git --command python3

"""Update script for gno package.

Custom updater needed because gno uses bun2nix: after each version
bump the bun.nix lockfile must be regenerated from the upstream bun.lock
using the bun2nix CLI.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    clone_and_generate_bun_nix,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.nix import nix_prefetch_url

PKG_DIR = Path(__file__).parent
FLAKE_ROOT = PKG_DIR.parent.parent
HASHES_FILE = PKG_DIR / "hashes.json"
BUN_NIX = PKG_DIR / "bun.nix"

OWNER = "gmickel"
REPO = "gno"


def main() -> None:
    """Update the gno package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating gno from {current} to {latest}")

    # Step 1: Calculate new source hash
    print("Calculating source hash...")
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/v{latest}.tar.gz"
    src_hash = nix_prefetch_url(url, unpack=True)
    print(f"  source hash: {src_hash}")

    # Step 2: Update hashes.json
    save_hashes(HASHES_FILE, {"version": latest, "hash": src_hash})
    print("Updated hashes.json")

    # Step 3: Regenerate bun.nix from upstream bun.lock
    clone_and_generate_bun_nix(
        OWNER,
        REPO,
        latest,
        BUN_NIX,
        FLAKE_ROOT,
        ref_prefix="v",
    )

    print(f"Updated gno to {latest}")


if __name__ == "__main__":
    main()
