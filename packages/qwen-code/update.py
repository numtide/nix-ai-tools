#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#prefetch-npm-deps --command python3

"""Update script for qwen-code package."""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    fetch_text,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH, calculate_url_hash
from updater.nix import NixCommandError, run_command

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
PACKAGE_NAME = "qwen-code"
GITHUB_OWNER = "QwenLM"
GITHUB_REPO = "qwen-code"


def download_package_lock(version: str) -> bool:
    """Download package-lock.json from GitHub for the given version."""
    url = f"https://raw.githubusercontent.com/{GITHUB_OWNER}/{GITHUB_REPO}/v{version}/package-lock.json"
    dest = SCRIPT_DIR / "package-lock.json"

    # Add GitHub token to request if available
    github_token = os.environ.get("GITHUB_TOKEN")
    print(f"Downloading package-lock.json from {url}...")
    try:
        # fetch_text handles authentication via urllib
        if github_token:
            import urllib.request
            req = urllib.request.Request(url)
            req.add_header("Authorization", f"token {github_token}")
            with urllib.request.urlopen(req) as response:
                content = response.read().decode("utf-8")
        else:
            content = fetch_text(url)
        
        dest.write_text(content)
        print("Successfully downloaded package-lock.json")
        return True
    except Exception as e:
        print(f"ERROR: Failed to download package-lock.json: {e}")
        return False


def run_nix_update(args: list[str]) -> None:
    """Run nix-update with given arguments."""
    cmd = ["nix-update", "--flake", PACKAGE_NAME] + args
    print(f"Running: {' '.join(cmd)}")
    result = run_command(cmd, check=False, capture_output=True)
    if result.returncode != 0:
        raise NixCommandError(f"nix-update failed: {result.stderr}")
    print(result.stdout)


def main() -> None:
    """Update the qwen-code package."""
    # Load current hashes
    data = load_hashes(HASHES_FILE)
    current_version = data["version"]
    print(f"Current version: {current_version}")

    # Load nix-update args to get version filter
    nix_update_args_file = SCRIPT_DIR / "nix-update-args"
    args = []
    if nix_update_args_file.exists():
        args = nix_update_args_file.read_text().strip().split("\n")
        args = [arg for arg in args if arg and not arg.startswith("#")]

    # Run nix-update to get the latest version and source hash
    print("Running nix-update...")
    try:
        run_nix_update(args)
    except NixCommandError as e:
        print(f"ERROR: {e}")
        return

    # Reload hashes to get updated version and hash from nix-update
    data = load_hashes(HASHES_FILE)
    new_version = data["version"]
    source_hash = data["hash"]
    print(f"New version: {new_version}")

    if not should_update(current_version, new_version):
        print("No update needed")
        return

    # Download the new package-lock.json
    if not download_package_lock(new_version):
        print("ERROR: Failed to update package-lock.json")
        return

    # Prepare data with dummy hash for npmDepsHash calculation
    new_data = {
        "version": new_version,
        "hash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }

    # Calculate npmDepsHash using the helper
    try:
        npm_deps_hash = calculate_dependency_hash(
            f".#{PACKAGE_NAME}",
            "npmDepsHash",
            HASHES_FILE,
            new_data,
        )
        new_data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, new_data)
        print(f"Successfully updated to version {new_version}")
    except (ValueError, NixCommandError) as e:
        print(f"ERROR: Failed to calculate npmDepsHash: {e}")
        return


if __name__ == "__main__":
    main()
