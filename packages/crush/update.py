#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for crush package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import nix_update


def main() -> None:
    """Update the crush package."""
    nix_update("crush", extra_args=["--version=stable"])


if __name__ == "__main__":
    main()
