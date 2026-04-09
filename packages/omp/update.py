#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#bun nixpkgs#git --command python3

"""Update script for omp (oh-my-pi) package.

Custom updater needed because omp uses both bun2nix (bun.nix must be
regenerated) and fetchCargoVendor (cargoHash must be recalculated) on
each version bump.  nix-update cannot handle either of these.
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    clone_and_generate_bun_nix,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

PKG_DIR = Path(__file__).parent
FLAKE_ROOT = PKG_DIR.parent.parent
HASHES_FILE = PKG_DIR / "hashes.json"
BUN_NIX = PKG_DIR / "bun.nix"

OWNER = "can1357"
REPO = "oh-my-pi"


def strip_workspace_entries(bun_nix: Path) -> None:
    """Remove workspace copyPathToStore entries from bun.nix.

    Workspace packages resolve relative to bun.nix, which is in
    packages/omp/ -- not the source root.  The bun2nix hook resolves
    workspace deps from the source tree during bun install, so these
    entries are unnecessary and would fail to evaluate.
    """
    text = bun_nix.read_text()
    text = re.sub(r"  copyPathToStore,\n", "", text)
    text = re.sub(
        r"  \"@oh-my-pi/[^\"]*\"\s*=\s*copyPathToStore\s+[^;]+;\n",
        "",
        text,
    )
    bun_nix.write_text(text)
    subprocess.run(
        ["nix", "fmt", "--", str(bun_nix)],
        cwd=FLAKE_ROOT,
        check=True,
        capture_output=True,
    )


def main() -> None:
    """Update the omp package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating omp from {current} to {latest}")

    # Step 1: Calculate new source hash
    print("Calculating source hash...")
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/v{latest}.tar.gz"
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Step 2: Regenerate bun.nix from upstream bun.lock
    clone_and_generate_bun_nix(
        OWNER,
        REPO,
        latest,
        BUN_NIX,
        FLAKE_ROOT,
        ref_prefix="v",
    )
    strip_workspace_entries(BUN_NIX)

    # Step 3: Calculate cargoHash
    try:
        cargo_hash = calculate_dependency_hash(".#omp", "cargoHash", HASHES_FILE, data)
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated omp to {latest}")


if __name__ == "__main__":
    main()
