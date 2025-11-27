#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex package."""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_github_latest_release, should_update
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build

HASHES_FILE = Path(__file__).parent / "hashes.json"


def fetch_version() -> str:
    """Fetch latest codex version from GitHub releases."""
    tag = fetch_github_latest_release("openai", "codex")
    match = re.match(r"^rust-v(.+)$", tag)
    return match.group(1) if match else tag


def calculate_cargo_hash(data: dict[str, str]) -> str:
    """Calculate cargoHash by building with dummy hash."""
    print("Calculating cargoHash...")
    original_hash = data["cargoHash"]

    data["cargoHash"] = DUMMY_SHA256_HASH
    HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")

    try:
        nix_build(".#codex", check=True)
        msg = "Build succeeded with dummy hash - unexpected"
        raise ValueError(msg)
    except NixCommandError as e:
        cargo_hash = extract_hash_from_build_error(e.args[0])
        if not cargo_hash:
            data["cargoHash"] = original_hash
            HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")
            msg = f"Could not extract hash from build error:\n{e.args[0]}"
            raise ValueError(msg) from e
        return cargo_hash


def main() -> None:
    """Update the codex package."""
    data = json.loads(HASHES_FILE.read_text())
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
    HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")

    try:
        cargo_hash = calculate_cargo_hash(data)
        data["cargoHash"] = cargo_hash
        HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
