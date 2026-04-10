#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for toon package.

Rust package from crates.io: fetches version from crates.io API,
prefetch source hash via fetchCrate, and recalculate cargo hash via dummy-hash build.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_json,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH

HASHES_FILE = Path(__file__).parent / "hashes.json"
CRATE_NAME = "toon-format"


def fetch_crates_version(crate: str) -> str:
    """Fetch the latest version from crates.io API."""
    url = f"https://crates.io/api/v1/crates/{crate}"
    data = fetch_json(url)
    if not isinstance(data, dict):
        msg = f"Expected dict from crates.io API, got {type(data)}"
        raise TypeError(msg)
    return data["crate"]["max_version"]


def main() -> None:
    """Update the toon package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_crates_version(CRATE_NAME)

    print(f"toon: current={current}, latest={latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    # Prefetch source hash using fetchCrate URL
    print(f"Prefetching {CRATE_NAME} v{latest} from crates.io...")
    src_hash = calculate_url_hash(
        f"https://crates.io/api/v1/crates/{CRATE_NAME}/{latest}/download",
        unpack=True,
    )
    data["version"] = latest
    data["hash"] = src_hash

    # Save intermediate hashes.json with dummy cargoHash
    data["cargoHash"] = DUMMY_SHA256_HASH
    save_hashes(HASHES_FILE, data)

    # Calculate real cargoHash via dummy-hash build
    print("Calculating cargoHash...")
    cargo_hash = calculate_dependency_hash(".#toon", "cargoHash", HASHES_FILE, data)
    data["cargoHash"] = cargo_hash

    save_hashes(HASHES_FILE, data)
    print(f"Updated {CRATE_NAME} to {latest}")


if __name__ == "__main__":
    main()
