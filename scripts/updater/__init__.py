"""Nix package updater library.

This library provides utilities for updating Nix packages in flakes,
including version fetching, hash calculation, and file modification.
"""

# Hash utilities
from .hash import calculate_url_hash

# HTTP utilities
from .http import fetch_text

# Nix commands
from .nix import (
    NixCommandError,
    nix_build,
    nix_eval,
)

# Version fetching
from .version import (
    fetch_github_latest_release,
    fetch_npm_version,
    should_update,
)

__all__ = [
    "NixCommandError",
    "calculate_url_hash",
    "fetch_github_latest_release",
    "fetch_npm_version",
    "fetch_text",
    "nix_build",
    "nix_eval",
    "should_update",
]
