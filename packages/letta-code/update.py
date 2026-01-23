#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for letta-code package."""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    extract_or_generate_lockfile,
    fetch_npm_version,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build

SCRIPT_DIR = Path(__file__).parent
PACKAGE_FILE = SCRIPT_DIR / "package.nix"
NPM_PACKAGE = "@letta-ai/letta-code"


def get_current_version() -> str:
    """Extract current version from package.nix."""
    content = PACKAGE_FILE.read_text()
    match = re.search(r'version = "([\d.]+)"', content)
    if not match:
        raise ValueError("Could not find version in package.nix")
    return match.group(1)


def update_package_nix(version: str, source_hash: str, npm_deps_hash: str) -> None:
    """Update version and hashes in package.nix."""
    content = PACKAGE_FILE.read_text()

    # Update version
    content = re.sub(r'version = "[\d.]+"', f'version = "{version}"', content)

    # Update source hash
    content = re.sub(
        r'hash = "sha256-[A-Za-z0-9+/=]+"',
        f'hash = "{source_hash}"',
        content,
        count=1,  # Only update the first occurrence (fetchurl)
    )

    # Update npm deps hash
    # Pattern matches: fetchNpmDepsWithPackuments { ... hash = "sha256-..." }
    # with flexible whitespace and line breaks
    content = re.sub(
        r'(fetchNpmDepsWithPackuments\s*\{[^}]*hash\s*=\s*)"sha256-[A-Za-z0-9+/=]+"',
        f'\\1"{npm_deps_hash}"',
        content,
        flags=re.DOTALL,
    )

    PACKAGE_FILE.write_text(content)


def main() -> None:
    """Update the letta-code package."""
    current = get_current_version()
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = f"https://registry.npmjs.org/{NPM_PACKAGE}/-/letta-code-{latest}.tgz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url)

    if not extract_or_generate_lockfile(
        tarball_url,
        SCRIPT_DIR / "package-lock.json",
        # Use legacy-peer-deps to resolve ink version conflicts
        env={"NPM_CONFIG_LEGACY_PEER_DEPS": "true"},
    ):
        return

    # Update package.nix with dummy npmDepsHash first
    update_package_nix(latest, source_hash, DUMMY_SHA256_HASH)

    # Calculate npmDepsHash by triggering a build failure
    try:
        # Try to build with dummy hash - this will fail and give us the correct hash
        result = nix_build(".#letta-code", check=False)
        npm_deps_hash = extract_hash_from_build_error(result.stderr or "")

        if not npm_deps_hash:
            raise ValueError("Could not extract npmDepsHash from build error")

        update_package_nix(latest, source_hash, npm_deps_hash)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
