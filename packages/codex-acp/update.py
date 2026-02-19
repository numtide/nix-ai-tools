#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex-acp package.

codex-acp depends on codex-core from the codex monorepo via a git dependency.
codex-core's build uses include_str!("../../../../node-version.txt") which
resolves outside the vendored crate. We need to track the codex git rev from
Cargo.lock and fetch node-version.txt from the same commit.
"""

import re
import sys
import tarfile
import tempfile
import urllib.request
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
from updater.nix import NixCommandError, nix_store_prefetch_file

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
OWNER = "zed-industries"
REPO = "codex-acp"


def extract_codex_rev_from_tarball(tag: str) -> str:
    """Download the release tarball and extract the codex git rev from Cargo.lock.

    The Cargo.lock pins codex crates to a specific commit on the 'acp' branch.
    """
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/{tag}.tar.gz"

    with tempfile.TemporaryDirectory() as tmpdir:
        tarball_path = Path(tmpdir) / "source.tar.gz"
        urllib.request.urlretrieve(url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            # Find Cargo.lock in the archive
            for member in tar.getmembers():
                if member.name.endswith("Cargo.lock"):
                    f = tar.extractfile(member)
                    if f is None:
                        continue
                    content = f.read().decode("utf-8")
                    match = re.search(
                        r"zed-industries/codex\?branch=acp#([a-f0-9]+)", content
                    )
                    if match:
                        return match.group(1)

    msg = "Could not extract codex git revision from Cargo.lock"
    raise ValueError(msg)


def main() -> None:
    """Update the codex-acp package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tag = f"v{latest}"
    print(f"Updating codex-acp to {latest}...")

    # Calculate source hash
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/{tag}.tar.gz"
    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    # Extract codex git rev from Cargo.lock in the new release
    print("Extracting codex git revision from Cargo.lock...")
    codex_rev = extract_codex_rev_from_tarball(tag)
    print(f"  codexRev: {codex_rev}")

    # Calculate codex source hash (needed for vendored bubblewrap on Linux)
    codex_src_url = (
        f"https://github.com/zed-industries/codex/archive/{codex_rev}.tar.gz"
    )
    print("Calculating codex source hash...")
    codex_src_hash = calculate_url_hash(codex_src_url, unpack=True)
    print(f"  codexSrcHash: {codex_src_hash}")

    # Calculate node-version.txt hash
    node_version_url = f"https://raw.githubusercontent.com/zed-industries/codex/{codex_rev}/codex-rs/node-version.txt"
    print("Calculating node-version.txt hash...")
    node_version_hash = nix_store_prefetch_file(node_version_url)
    print(f"  nodeVersionHash: {node_version_hash}")

    # Save with dummy cargoHash to calculate the real one
    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "codexRev": codex_rev,
        "codexSrcHash": codex_src_hash,
        "nodeVersionHash": node_version_hash,
    }
    save_hashes(HASHES_FILE, data)

    try:
        cargo_hash = calculate_dependency_hash(
            ".#codex-acp", "cargoHash", HASHES_FILE, data
        )
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error calculating cargoHash: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
