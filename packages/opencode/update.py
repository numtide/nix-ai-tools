#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for opencode package."""

import subprocess
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    get_node_modules_hash,
    nix_update,
    update_hash,
)


def main() -> None:
    """Update opencode package and node_modules hash."""
    package = "opencode"
    script_dir = Path(__file__).parent.resolve()
    package_file = script_dir / "package.nix"

    # Read original content to detect changes
    original_content = package_file.read_text()

    # Step 1: Update the main package version and source hash
    nix_update(package)

    # Check if there were changes by comparing file content
    current_content = package_file.read_text()
    if current_content != original_content:
        # Step 2: Update node_modules hash
        try:
            new_hash = get_node_modules_hash(package, package_file)
            update_hash(package_file, "outputHash", new_hash)
            print(f"Updated {package} and node_modules hash!")
        except (subprocess.CalledProcessError, ValueError) as e:
            print(f"Error updating node_modules hash: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"{package} is already up-to-date!")


if __name__ == "__main__":
    main()
