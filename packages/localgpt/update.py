#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#cargo --command python3

"""Update script for localgpt package.

Custom updater is needed because we enable additional Cargo features (x11,
wayland) that pull in dependencies not present in the upstream Cargo.lock.
After each version bump the lockfile patch must be regenerated.
"""

import subprocess
import sys
import tempfile
from pathlib import Path
from typing import cast

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.http import fetch_json
from updater.nix import NixCommandError, nix_prefetch_url

PKG_DIR = Path(__file__).parent
HASHES_FILE = PKG_DIR / "hashes.json"
PATCH_FILE = PKG_DIR / "update-lockfile.patch"


def fetch_latest_tag(owner: str, repo: str) -> str:
    """Fetch the latest tag version from GitHub (for repos without releases)."""
    url = f"https://api.github.com/repos/{owner}/{repo}/tags?per_page=1"
    data = fetch_json(url)
    if not isinstance(data, list) or not data:
        msg = f"No tags found for {owner}/{repo}"
        raise ValueError(msg)
    tag = cast("str", data[0]["name"])
    return tag.lstrip("v")


def generate_lockfile_patch(version: str) -> None:
    """Clone the repo, enable x11/wayland features, and generate lockfile patch."""
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = Path(tmpdir) / "localgpt"

        print("Cloning source...")
        subprocess.run(
            [
                "git",
                "clone",
                "--depth=1",
                f"--branch=v{version}",
                "https://github.com/localgpt-app/localgpt.git",
                str(repo_dir),
            ],
            check=True,
            capture_output=True,
        )

        # Save original Cargo.lock
        cargo_lock_orig = (repo_dir / "Cargo.lock").read_text()

        # Apply the same Cargo.toml feature modification as postPatch
        cargo_toml = repo_dir / "Cargo.toml"
        toml_text = cargo_toml.read_text()
        toml_text = toml_text.replace(
            "default-features = false, features = [",
            'default-features = false, features = ["x11", "wayland",',
        )
        cargo_toml.write_text(toml_text)

        # Update lockfile minimally — only resolve newly required deps
        # without bumping existing ones (cargo generate-lockfile would
        # re-resolve everything from scratch).
        print("Updating Cargo.lock...")
        subprocess.run(
            ["cargo", "update", "--workspace"],
            check=True,
            capture_output=True,
            cwd=repo_dir,
        )

        cargo_lock_new = (repo_dir / "Cargo.lock").read_text()

        if cargo_lock_orig == cargo_lock_new:
            print("No lockfile changes needed, removing patch")
            PATCH_FILE.write_text("")
            return

        # Write the files for diff
        print("Generating lockfile patch...")
        a_dir = Path(tmpdir) / "a"
        b_dir = Path(tmpdir) / "b"
        a_dir.mkdir()
        b_dir.mkdir()
        (a_dir / "Cargo.lock").write_text(cargo_lock_orig)
        (b_dir / "Cargo.lock").write_text(cargo_lock_new)

        result = subprocess.run(
            ["diff", "-u", "a/Cargo.lock", "b/Cargo.lock"],
            capture_output=True,
            text=True,
            check=False,
            cwd=tmpdir,
        )
        # diff returns 1 when files differ, which is expected
        patch_content = result.stdout
        PATCH_FILE.write_text(patch_content)
        print(f"Wrote {PATCH_FILE.name} ({len(patch_content.splitlines())} lines)")


def main() -> None:
    """Update the localgpt package."""
    data = load_hashes(HASHES_FILE)
    current: str = data["version"]
    latest = fetch_latest_tag("localgpt-app", "localgpt")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating localgpt from {current} to {latest}")

    # Step 1: Calculate new source hash
    print("Calculating source hash...")
    url = f"https://github.com/localgpt-app/localgpt/archive/refs/tags/v{latest}.tar.gz"
    source_hash = nix_prefetch_url(url, unpack=True)

    # Step 2: Regenerate the Cargo.lock patch
    generate_lockfile_patch(latest)

    # Step 3: Save version + source hash, dummy cargoHash for dep calculation
    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Step 4: Calculate cargoHash via nix build (Linux-only package)
    try:
        cargo_hash = calculate_dependency_hash(
            ".#packages.x86_64-linux.localgpt", "cargoHash", HASHES_FILE, data
        )
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error calculating cargoHash: {e}")
        return

    print(f"Updated localgpt to {latest}")


if __name__ == "__main__":
    main()
