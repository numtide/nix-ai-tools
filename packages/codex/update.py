#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import nix_update


def main() -> None:
    """Update the codex package."""
    nix_update(
        "codex",
        extra_args=["--version-regex", r"^rust-v(\d+\.\d+\.\d+)$"],
    )


if __name__ == "__main__":
    main()
