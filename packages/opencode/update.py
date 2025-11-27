#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for opencode package."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_github_latest_release, should_update
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build

HASHES_FILE = Path(__file__).parent / "hashes.json"


def calculate_output_hash(data: dict[str, str]) -> str:
    """Calculate outputHash for node_modules by building with dummy hash."""
    print("Calculating outputHash for node_modules...")
    original_hash = data["outputHash"]

    data["outputHash"] = DUMMY_SHA256_HASH
    HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")

    try:
        nix_build(".#opencode", check=True)
        msg = "Build succeeded with dummy hash - unexpected"
        raise ValueError(msg)
    except NixCommandError as e:
        output_hash = extract_hash_from_build_error(e.args[0])
        if not output_hash:
            data["outputHash"] = original_hash
            HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")
            msg = f"Could not extract hash from build error:\n{e.args[0]}"
            raise ValueError(msg) from e
        return output_hash


def main() -> None:
    """Update the opencode package."""
    data = json.loads(HASHES_FILE.read_text())
    current = data["version"]
    latest = fetch_github_latest_release("sst", "opencode")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tag = f"v{latest}"
    url = f"https://github.com/sst/opencode/archive/refs/tags/{tag}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        "outputHash": DUMMY_SHA256_HASH,
    }
    HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")

    try:
        output_hash = calculate_output_hash(data)
        data["outputHash"] = output_hash
        HASHES_FILE.write_text(json.dumps(data, indent=2) + "\n")
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
