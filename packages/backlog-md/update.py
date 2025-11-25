#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for backlog-md package."""

import json
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_github_latest_release, nix_eval
from updater.hash import extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build


def main() -> None:
    """Update the backlog-md package."""
    script_dir = Path(__file__).parent
    sources_file = script_dir / "sources.json"

    # Get current version (backlog-md is x86_64-linux only)
    current = nix_eval(".#packages.x86_64-linux.backlog-md.version")
    latest = fetch_github_latest_release("MrLesk", "Backlog.md")

    if current == latest:
        print("backlog-md is already up-to-date!")
        return

    print(f"Updating backlog-md from {current} to {latest}")

    # Calculate source hash for fetchFromGitHub
    tag = f"v{latest}"
    url = f"https://github.com/MrLesk/Backlog.md/archive/{tag}.tar.gz"
    print("Fetching source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    # Write temporary sources.json with dummy node_modules hash
    sources = {
        "version": latest,
        "src_hash": source_hash,
        "node_modules_hash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    }
    sources_file.write_text(json.dumps(sources, indent=2) + "\n")

    # Calculate correct node_modules hash by building (backlog-md is x86_64-linux only)
    print("Building to get node_modules hash...")
    try:
        nix_build(".#packages.x86_64-linux.backlog-md", check=True)
        # If build succeeds, something went wrong
        print("Warning: Build succeeded with dummy hash - using dummy hash")
        node_modules_hash = sources["node_modules_hash"]
    except NixCommandError as e:
        # Extract hash from error
        error_output = e.args[0] if e.args else str(e)
        extracted_hash = extract_hash_from_build_error(error_output)
        if not extracted_hash:
            print(f"Error: Could not extract hash from build error:\n{error_output}")
            return
        node_modules_hash = extracted_hash
        print(f"Extracted node_modules hash: {node_modules_hash}")

    # Write final sources.json with all correct values
    sources["node_modules_hash"] = node_modules_hash
    sources_file.write_text(json.dumps(sources, indent=2) + "\n")
    print(f"Updated sources.json with version {latest}")
    print("Update complete for backlog-md!")


if __name__ == "__main__":
    main()
