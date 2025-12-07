#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for claude-code package."""

import os
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from urllib.request import urlretrieve

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
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


def generate_package_lock(tarball_url: str) -> None:
    """Generate package-lock.json from tarball."""
    print("Generating package-lock.json...")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        tarball_path = tmpdir_path / "claude-code.tgz"
        urlretrieve(tarball_url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir_path, filter="data")

        package_dir = tmpdir_path / "package"

        subprocess.run(
            ["npm", "install", "--package-lock-only"],
            cwd=package_dir,
            # `claude-code` has a `prepare` script that requires `AUTHORIZED=1`
            env={**os.environ, "AUTHORIZED": "1"},
            check=True,
        )

        (SCRIPT_DIR / "package-lock.json").write_text(
            (package_dir / "package-lock.json").read_text()
        )


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

    generate_package_lock(tarball_url)

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
