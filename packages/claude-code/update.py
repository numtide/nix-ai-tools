#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for claude-code package."""

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_npm_version, should_update
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
NPM_PACKAGE = "@anthropic-ai/claude-code"


def generate_package_lock(version: str) -> None:
    """Generate package-lock.json for the given version."""
    print("Updating package-lock.json...")
    subprocess.run(
        ["npm", "i", "--package-lock-only", f"{NPM_PACKAGE}@{version}"],
        cwd=SCRIPT_DIR,
        check=True,
    )
    # Clean up temporary package.json if created
    package_json = SCRIPT_DIR / "package.json"
    if package_json.exists():
        package_json.unlink()


def calculate_npm_deps_hash(data: dict[str, str]) -> str:
    """Calculate npmDepsHash by building with dummy hash."""
    print("Calculating npmDepsHash...")
    original_hash = data["npmDepsHash"]

    # Write dummy hash
    data["npmDepsHash"] = DUMMY_SHA256_HASH
    HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")

    try:
        nix_build(".#claude-code", check=True)
        msg = "Build succeeded with dummy hash - unexpected"
        raise ValueError(msg)
    except NixCommandError as e:
        npm_deps_hash = extract_hash_from_build_error(e.args[0])
        if not npm_deps_hash:
            # Restore original
            data["npmDepsHash"] = original_hash
            HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")
            msg = f"Could not extract hash from build error:\n{e.args[0]}"
            raise ValueError(msg) from e
        return npm_deps_hash


def main() -> None:
    """Update the claude-code package."""
    data = json.loads(HASHES_FILE.read_text())
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = f"https://registry.npmjs.org/{NPM_PACKAGE}/-/claude-code-{latest}.tgz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url, unpack=True)

    # Generate package-lock.json
    generate_package_lock(latest)

    # Update hashes.json
    data = {
        "version": latest,
        "hash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")

    # Calculate npmDepsHash
    try:
        npm_deps_hash = calculate_npm_deps_hash(data)
        data["npmDepsHash"] = npm_deps_hash
        HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
