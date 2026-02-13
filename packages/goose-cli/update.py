#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for goose-cli package.

This script updates both the goose-cli version and the librusty_v8 hashes.
The v8 version is extracted from the Cargo.lock file of the goose repository.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    fetch_text,
    load_hashes,
    save_hashes,
)

HASHES_FILE = Path(__file__).parent / "librusty_v8_hashes.json"

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
    
    # Parse the Cargo.lock to find v8 version
    lines = cargo_lock.split('\n')
    for i, line in enumerate(lines):
        if line.strip() == 'name = "v8"':
            # Look for version in the next few lines
            for j in range(i + 1, min(i + 10, len(lines))):
                if 'version = ' in lines[j]:
                    version = lines[j].split('"')[1]
                    return version
    
    raise ValueError("Could not find v8 version in Cargo.lock")


def main() -> None:
    """Update the librusty_v8 hashes for goose-cli."""
    # Read the current goose-cli version from package.nix
    package_nix = (Path(__file__).parent / "package.nix").read_text()
    for line in package_nix.split('\n'):
        if 'version = ' in line and '"' in line:
            goose_version = line.split('"')[1]
            break
    else:
        raise ValueError("Could not find version in package.nix")
    
    print(f"Goose version: {goose_version}")
    
    # Get the v8 version from Cargo.lock
    v8_version = fetch_v8_version_from_cargo_lock(goose_version)
    print(f"V8 version: {v8_version}")
    
    # Check if we need to update
    try:
        data = load_hashes(HASHES_FILE)
        current_v8 = data.get("version", "")
        if current_v8 == v8_version:
            print(f"V8 hashes already up to date ({v8_version})")
            return
    except FileNotFoundError:
        print("No existing hashes file, creating new one")
    
    # Calculate hashes for all platforms
    url_template = f"https://github.com/denoland/rusty_v8/releases/download/v{v8_version}/librusty_v8_release_{{platform}}.a.gz"
    hashes = calculate_platform_hashes(url_template, PLATFORMS)
    
    # Save the hashes
    save_hashes(HASHES_FILE, {"version": v8_version, "hashes": hashes})
    
    # Update librusty_v8.nix
    librusty_v8_nix = Path(__file__).parent / "librusty_v8.nix"
    content = f'''# Pre-built librusty_v8 library for goose-cli
# This file specifies the rusty_v8 version and hashes for all supported platforms
{{ fetchLibrustyV8 }}:

fetchLibrustyV8 {{
  version = "{v8_version}";
  shas = {{
    x86_64-linux = "{hashes['x86_64-linux']}";
    aarch64-linux = "{hashes['aarch64-linux']}";
    x86_64-darwin = "{hashes['x86_64-darwin']}";
    aarch64-darwin = "{hashes['aarch64-darwin']}";
  }};
}}
'''
    librusty_v8_nix.write_text(content)
    
    print(f"Updated librusty_v8 to {v8_version}")


if __name__ == "__main__":
    main()
