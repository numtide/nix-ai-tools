#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for goose-server package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_platform_hashes,
    calculate_url_hash,
    fetch_github_latest_release,
    fetch_text,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "x86_64-unknown-linux-gnu",
    "aarch64-linux": "aarch64-unknown-linux-gnu",
    "x86_64-darwin": "x86_64-apple-darwin",
    "aarch64-darwin": "aarch64-apple-darwin",
}


def fetch_v8_version_from_cargo_lock(goose_version: str) -> str:
    """Extract the v8 version from goose's Cargo.lock file."""
    url = f"https://raw.githubusercontent.com/block/goose/v{goose_version}/Cargo.lock"
    cargo_lock = fetch_text(url)

    lines = cargo_lock.split("\n")
    for i, line in enumerate(lines):
        if line.strip() == 'name = "v8"':
            for j in range(i + 1, min(i + 10, len(lines))):
                if "version = " in lines[j]:
                    return lines[j].split('"')[1]

    msg = "Could not find v8 version in Cargo.lock"
    raise ValueError(msg)


def main() -> None:
    """Update the goose-server package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release("block", "goose")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    source_url = f"https://github.com/block/goose/archive/refs/tags/v{latest}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(source_url, unpack=True)

    v8_version = fetch_v8_version_from_cargo_lock(latest)
    previous_v8 = data.get("librusty_v8")
    if previous_v8 and previous_v8.get("version") == v8_version:
        v8_hashes = previous_v8["hashes"]
    else:
        print(f"V8 version: {v8_version}")
        v8_hashes = calculate_platform_hashes(
            "https://github.com/denoland/rusty_v8/releases/download/"
            "v{version}/librusty_v8_release_{platform}.a.gz",
            PLATFORMS,
            version=v8_version,
        )

    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "librusty_v8": {
            "version": v8_version,
            "hashes": v8_hashes,
        },
    }
    save_hashes(HASHES_FILE, data)

    try:
        cargo_hash = calculate_dependency_hash(
            ".#goose-server", "cargoHash", HASHES_FILE, data
        )
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
