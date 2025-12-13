#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#prefetch-npm-deps --command python3

"""Update script for qwen-code package."""

import subprocess
import sys
from pathlib import Path
from urllib.request import urlretrieve

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import NixCommandError, nix_eval

SCRIPT_DIR = Path(__file__).parent
PACKAGE_NAME = "qwen-code"
GITHUB_OWNER = "QwenLM"
GITHUB_REPO = "qwen-code"


def download_package_lock(version: str) -> bool:
    """Download package-lock.json from GitHub for the given version."""
    url = f"https://raw.githubusercontent.com/{GITHUB_OWNER}/{GITHUB_REPO}/v{version}/package-lock.json"
    dest = SCRIPT_DIR / "package-lock.json"

    print(f"Downloading package-lock.json from {url}...")
    try:
        urlretrieve(url, dest)
        print("Successfully downloaded package-lock.json")
        return True
    except Exception as e:
        print(f"ERROR: Failed to download package-lock.json: {e}")
        return False


def calculate_npm_deps_hash() -> str:
    """Calculate npmDepsHash using prefetch-npm-deps."""
    package_lock = SCRIPT_DIR / "package-lock.json"
    print("Calculating npmDepsHash...")
    result = subprocess.run(
        ["prefetch-npm-deps", str(package_lock)],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def run_nix_update(args: list[str]) -> None:
    """Run nix-update with given arguments."""
    cmd = ["nix-update", "--flake", PACKAGE_NAME] + args
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise NixCommandError(f"nix-update failed: {result.stderr}")
    print(result.stdout)


def main() -> None:
    """Update the qwen-code package."""
    # Get current version
    current_version = nix_eval(f".#packages.x86_64-linux.{PACKAGE_NAME}.version")
    print(f"Current version: {current_version}")

    # Load nix-update args
    nix_update_args_file = SCRIPT_DIR / "nix-update-args"
    args = []
    if nix_update_args_file.exists():
        args = nix_update_args_file.read_text().strip().split("\n")
        args = [arg for arg in args if arg and not arg.startswith("#")]

    # Run nix-update to update version and source hash
    print("Running nix-update...")
    try:
        run_nix_update(args)
    except NixCommandError as e:
        print(f"ERROR: {e}")
        return

    # Get new version after nix-update
    new_version = nix_eval(f".#packages.x86_64-linux.{PACKAGE_NAME}.version")
    print(f"New version: {new_version}")

    if current_version == new_version:
        print("No update needed")
        return

    # Download the new package-lock.json
    if not download_package_lock(new_version):
        print("ERROR: Failed to update package-lock.json")
        return

    # Calculate npmDepsHash
    try:
        npm_deps_hash = calculate_npm_deps_hash()
        print(f"npmDepsHash: {npm_deps_hash}")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to calculate npmDepsHash: {e}")
        return

    # Update package.nix with the new npmDepsHash
    package_nix = SCRIPT_DIR / "package.nix"
    content = package_nix.read_text()

    # Find and replace npmDepsHash line
    lines = content.split("\n")
    for i, line in enumerate(lines):
        if "npmDepsHash" in line and "=" in line:
            # Preserve indentation
            indent = len(line) - len(line.lstrip())
            lines[i] = " " * indent + f'npmDepsHash = "{npm_deps_hash}";'
            break

    package_nix.write_text("\n".join(lines))
    print(f"Successfully updated to version {new_version}")


if __name__ == "__main__":
    main()
