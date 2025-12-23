#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for openspec package."""

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
NPM_PACKAGE = "@fission-ai/openspec"


def extract_package_lock(tarball_url: str) -> bool:
    """Extract package-lock.json from tarball or generate it."""
    print("Extracting package-lock.json from tarball...")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        tarball_path = tmpdir_path / "openspec.tgz"
        urlretrieve(tarball_url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir_path, filter="data")

        package_dir = tmpdir_path / "package"
        package_lock_src = package_dir / "package-lock.json"

        if package_lock_src.exists():
            (SCRIPT_DIR / "package-lock.json").write_text(package_lock_src.read_text())
            print("Updated package-lock.json from tarball")
            return True

        # Generate if not in tarball
        print("No package-lock.json in tarball, generating...")
        if not (package_dir / "package.json").exists():
            print("ERROR: No package.json found!")
            return False

        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=package_dir,
            check=True,
        )

        new_lock = package_dir / "package-lock.json"
        if new_lock.exists():
            (SCRIPT_DIR / "package-lock.json").write_text(new_lock.read_text())
            print("Generated package-lock.json")
            return True

        print("ERROR: Failed to generate package-lock.json")
        return False


def main() -> None:
    """Update the openspec package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = f"https://registry.npmjs.org/{NPM_PACKAGE}/-/openspec-{latest}.tgz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url)

    if not extract_package_lock(tarball_url):
        return

    # Update hashes.json
    data = {
        "version": latest,
        "sourceHash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Calculate npmDepsHash
    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#openspec", "npmDepsHash", HASHES_FILE, data
        )
        data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
