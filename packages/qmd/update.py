#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs nixpkgs#jq --command python3

"""Update script for qmd package."""

import json
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import cast
from urllib.request import urlretrieve

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_json,
    load_hashes,
    save_hashes,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
OWNER = "tobi"
REPO = "qmd"


def fetch_latest_commit() -> tuple[str, str]:
    """Fetch the latest commit SHA and date from the default branch.

    Returns:
        Tuple of (commit SHA, commit date in YYYY-MM-DD format)

    """
    url = f"https://api.github.com/repos/{OWNER}/{REPO}/commits/main"
    data = fetch_json(url)
    if not isinstance(data, dict):
        msg = f"Expected dict from GitHub API, got {type(data)}"
        raise TypeError(msg)

    sha = cast("str", data["sha"])
    # commit.committer.date is in ISO 8601 format
    commit_date = cast("str", data["commit"]["committer"]["date"])[:10]
    return sha, commit_date


def generate_lockfile_from_github(rev: str, output_path: Path) -> bool:
    """Generate package-lock.json from GitHub tarball.

    Downloads the GitHub tarball, extracts package.json, removes win32
    optional dependency, and generates package-lock.json.

    Args:
        rev: Git commit SHA
        output_path: Path where package-lock.json should be written

    Returns:
        True if lockfile was successfully generated, False otherwise

    """
    print("Generating package-lock.json from GitHub tarball...")

    tarball_url = f"https://github.com/{OWNER}/{REPO}/archive/{rev}.tar.gz"

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        tarball_path = tmpdir_path / "package.tgz"
        urlretrieve(tarball_url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir_path, filter="data")

        # GitHub archives extract to {repo}-{sha}/
        package_dirs = list(tmpdir_path.glob(f"{REPO}-*"))
        if not package_dirs:
            print("ERROR: Could not find extracted package directory!")
            return False

        package_dir = package_dirs[0]
        package_json = package_dir / "package.json"

        if not package_json.exists():
            print("ERROR: No package.json found!")
            return False

        # Remove win32 optional dependency to match build configuration
        with package_json.open() as f:
            pkg_data = json.load(f)

        if "optionalDependencies" in pkg_data:
            pkg_data["optionalDependencies"].pop("sqlite-vec-win32-x64", None)

        with package_json.open("w") as f:
            json.dump(pkg_data, f, indent=2)

        # Generate package-lock.json
        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=package_dir,
            check=True,
        )

        new_lock = package_dir / "package-lock.json"
        if new_lock.exists():
            output_path.write_text(new_lock.read_text())
            print("Generated package-lock.json")
            return True

        print("ERROR: Failed to generate package-lock.json")
        return False


def main() -> None:
    """Update the qmd package."""
    data = load_hashes(HASHES_FILE)
    current_rev = data["rev"]

    latest_rev, commit_date = fetch_latest_commit()
    print(f"Current rev: {current_rev[:8]}")
    print(f"Latest rev:  {latest_rev[:8]} ({commit_date})")

    if current_rev == latest_rev:
        print("Already up to date")
        return

    print(f"Updating qmd to {latest_rev[:8]}...")

    # Calculate new source hash
    tarball_url = f"https://github.com/{OWNER}/{REPO}/archive/{latest_rev}.tar.gz"
    print(f"Calculating source hash for {tarball_url}...")
    src_hash = calculate_url_hash(tarball_url, unpack=True)
    print(f"  srcHash: {src_hash}")

    # Generate package-lock.json
    if not generate_lockfile_from_github(
        latest_rev, SCRIPT_DIR / "package-lock.json"
    ):
        return

    # Update hashes.json with dummy npmDepsHash
    new_data = {
        "rev": latest_rev,
        "srcHash": src_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, new_data)

    # Calculate npmDepsHash
    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#qmd", "npmDepsHash", HASHES_FILE, new_data
        )
        new_data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, new_data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest_rev[:8]} ({commit_date})")


if __name__ == "__main__":
    main()
