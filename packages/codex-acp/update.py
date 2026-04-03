#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex-acp package.

codex-acp depends on codex crates from a git source. codex-core's build uses
include_str!("../../../../node-version.txt"), which resolves outside the
vendored crate. We track the pinned codex source from Cargo.lock and fetch
node-version.txt from the same commit.
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
    calculate_platform_hashes,
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
PLATFORMS = {
    "x86_64-linux": "x86_64-unknown-linux-gnu",
    "aarch64-linux": "aarch64-unknown-linux-gnu",
    "x86_64-darwin": "x86_64-apple-darwin",
    "aarch64-darwin": "aarch64-apple-darwin",
}


def extract_release_pins_from_tarball(tag: str) -> tuple[str, str, str]:
    """Download the release tarball and extract pinned versions from Cargo.lock."""
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
                    codex_match = re.search(
                        r'source = "git\+https://github\.com/([^/]+)/codex\?[^"#]+#([a-f0-9]+)"',
                        content,
                    )
                    v8_match = re.search(r'name = "v8"\nversion = "([^"]+)"', content)
                    if codex_match and v8_match:
                        return (
                            codex_match.group(1),
                            codex_match.group(2),
                            v8_match.group(1),
                        )

    msg = "Could not extract codex and v8 pins from Cargo.lock"
    raise ValueError(msg)


def librusty_v8_pins(
    v8_version: str, previous: dict[str, object] | None
) -> dict[str, object]:
    """Return the librusty_v8 pin for the given v8 version."""
    print(f"V8 version: {v8_version}")

    if previous and previous.get("version") == v8_version:
        print("V8 unchanged, reusing hashes")
        return previous

    hashes = calculate_platform_hashes(
        "https://github.com/denoland/rusty_v8/releases/download/"
        "v{version}/librusty_v8_release_{platform}.a.gz",
        PLATFORMS,
        version=v8_version,
    )
    return {"version": v8_version, "hashes": {k: hashes[k] for k in PLATFORMS}}


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

    # Extract release pins from Cargo.lock in the new release
    print("Extracting release pins from Cargo.lock...")
    codex_owner, codex_rev, v8_version = extract_release_pins_from_tarball(tag)
    print(f"  codexOwner: {codex_owner}")
    print(f"  codexRev: {codex_rev}")

    # Calculate codex source hash (needed for vendored bubblewrap on Linux)
    codex_src_url = f"https://github.com/{codex_owner}/codex/archive/{codex_rev}.tar.gz"
    print("Calculating codex source hash...")
    codex_src_hash = calculate_url_hash(codex_src_url, unpack=True)
    print(f"  codexSrcHash: {codex_src_hash}")

    # Calculate node-version.txt hash
    node_version_url = f"https://raw.githubusercontent.com/{codex_owner}/codex/{codex_rev}/codex-rs/node-version.txt"
    print("Calculating node-version.txt hash...")
    node_version_hash = nix_store_prefetch_file(node_version_url)
    print(f"  nodeVersionHash: {node_version_hash}")

    # Save with dummy cargoHash to calculate the real one
    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "codexOwner": codex_owner,
        "codexRev": codex_rev,
        "codexSrcHash": codex_src_hash,
        "librusty_v8": librusty_v8_pins(v8_version, data.get("librusty_v8")),
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
