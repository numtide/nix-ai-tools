#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for agent-browser package.

Fetches the latest version from npm registry and updates hashes.
Uses upstream's pnpm-lock.yaml directly (no lockfile generation needed).

Calculates cargoHash and pnpmDepsHash in parallel by targeting specific
sub-derivations instead of the full package build, avoiding the CI timeout
that occurred when building everything sequentially.
"""

import concurrent.futures
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    load_hashes,
    save_hashes,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError
from updater.version import fetch_npm_version, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"


def main() -> None:
    """Update the agent-browser package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version("agent-browser")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    # Calculate new src hash from GitHub
    url = f"https://github.com/vercel-labs/agent-browser/archive/refs/tags/v{latest}.tar.gz"
    print("Calculating source hash...")
    src_hash = calculate_url_hash(url, unpack=True)

    # Save with dummy hashes for both cargo and pnpm deps, then calculate
    # both in parallel by targeting specific sub-derivations:
    # - cargoHash via the Rust binary derivation (no pnpm deps needed)
    # - pnpmDepsHash via the pnpm deps derivation (no Rust build needed)
    data = {
        "version": latest,
        "hash": src_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "pnpmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Target sub-derivations to avoid unnecessary work:
    # - .passthru.agent-browser-native-binary only evaluates cargoHash
    # - .pnpmDeps only evaluates pnpmDepsHash
    # This avoids the sequential full-package builds that caused CI timeouts
    # (each full build would redundantly compile the other component).
    cargo_attr = ".#agent-browser.passthru.agent-browser-native-binary"
    pnpm_attr = ".#agent-browser.pnpmDeps"

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        cargo_future = executor.submit(
            calculate_dependency_hash,
            cargo_attr,
            "cargoHash",
            HASHES_FILE,
            data.copy(),
        )
        pnpm_future = executor.submit(
            calculate_dependency_hash,
            pnpm_attr,
            "pnpmDepsHash",
            HASHES_FILE,
            data.copy(),
        )

        errors: list[str] = []

        try:
            cargo_hash = cargo_future.result()
            print(f"cargoHash: {cargo_hash}")
        except (ValueError, NixCommandError) as e:
            errors.append(f"cargoHash error: {e}")
            cargo_hash = None

        try:
            pnpm_deps_hash = pnpm_future.result()
            print(f"pnpmDepsHash: {pnpm_deps_hash}")
        except (ValueError, NixCommandError) as e:
            errors.append(f"pnpmDepsHash error: {e}")
            pnpm_deps_hash = None

    if errors:
        for err in errors:
            print(f"Error: {err}")
        return

    # Write final hashes
    data["cargoHash"] = cargo_hash
    data["pnpmDepsHash"] = pnpm_deps_hash
    save_hashes(HASHES_FILE, data)

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
