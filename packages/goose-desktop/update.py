#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Wrapper update script for goose-desktop.

Shared Goose metadata lives under packages/goose-cli/, so delegate there.
"""

import subprocess
import sys
from pathlib import Path


def main() -> None:
    script = Path(__file__).resolve().parents[1] / "goose-cli" / "update.py"
    raise SystemExit(
        subprocess.run([sys.executable, str(script)], check=False).returncode
    )


if __name__ == "__main__":
    main()
