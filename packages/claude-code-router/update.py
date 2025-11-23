#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for claude-code-router package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import NpmPackageUpdater


def main() -> None:
    """Update the claude-code-router package."""
    updater = NpmPackageUpdater(
        package="claude-code-router",
        npm_package_name="@musistudio/claude-code-router",
        has_npm_deps_hash=False,
    )
    updater.update()


if __name__ == "__main__":
    main()
