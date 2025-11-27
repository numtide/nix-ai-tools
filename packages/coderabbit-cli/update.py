#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for coderabbit-cli package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    fetch_text,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def fetch_version() -> str:
    """Fetch the latest version from CodeRabbit's VERSION endpoint."""
    return fetch_text("https://cli.coderabbit.ai/releases/latest/VERSION").strip()


def main() -> None:
    """Update the coderabbit-cli package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url_template = (
        f"https://cli.coderabbit.ai/releases/{latest}/coderabbit-{{platform}}.zip"
    )
    hashes = calculate_platform_hashes(url_template, PLATFORMS)

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
