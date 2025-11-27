#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex package."""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

HASHES_FILE = Path(__file__).parent / "hashes.json"


def fetch_version() -> str:
    """Fetch latest codex version from GitHub releases."""
    tag = fetch_github_latest_release("openai", "codex")
    match = re.match(r"^rust-v(.+)$", tag)
    if not match:
        msg = f"Unexpected tag format: {tag!r}, expected 'rust-v<version>'"
        raise ValueError(msg)
    return match.group(1)


def main() -> None:
    """Update the codex package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tag = f"rust-v{latest}"
    url = f"https://github.com/openai/codex/archive/refs/tags/{tag}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    try:
        cargo_hash = calculate_dependency_hash(
            ".#codex", "cargoHash", HASHES_FILE, data
        )
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
