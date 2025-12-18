#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for claude-native package."""

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
INSTALL_SCRIPT_URL = "https://claude.ai/install.sh"

PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def get_bucket_url() -> str:
    """Discover bucket URL from the official install script."""
    script = fetch_text(INSTALL_SCRIPT_URL)
    for line in script.splitlines():
        if line.startswith("GCS_BUCKET="):
            return line.split("=", 1)[1].strip('"')
    msg = "Could not find GCS_BUCKET in install script"
    raise ValueError(msg)


def main() -> None:
    """Update the claude-code-native package."""
    bucket = get_bucket_url()
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_text(f"{bucket}/stable").strip()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url_template = f"{bucket}/{latest}/{{platform}}/claude"
    hashes = calculate_platform_hashes(url_template, PLATFORMS)

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
