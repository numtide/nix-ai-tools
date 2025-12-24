"""Nix package updater library.

This library provides utilities for updating Nix packages in flakes,
including version fetching, hash calculation, and file modification.
"""

# Dependency hash calculation
from .deps import calculate_dependency_hash

# Hash utilities
from .hash import calculate_url_hash

# Hashes file I/O
from .hashes_file import load_hashes, save_hashes

# HTTP utilities
from .http import fetch_json, fetch_text

# Nix commands
from .nix import (
    NixCommandError,
    nix_build,
    nix_eval,
)

# NPM utilities
from .npm import extract_or_generate_lockfile

# Platform utilities
from .platforms import calculate_platform_hashes

# Version fetching
from .version import (
    fetch_github_latest_release,
    fetch_npm_version,
    fetch_version_from_text,
    should_update,
)

__all__ = [
    "NixCommandError",
    "calculate_dependency_hash",
    "calculate_platform_hashes",
    "calculate_url_hash",
    "extract_or_generate_lockfile",
    "fetch_github_latest_release",
    "fetch_json",
    "fetch_npm_version",
    "fetch_text",
    "fetch_version_from_text",
    "load_hashes",
    "nix_build",
    "nix_eval",
    "save_hashes",
    "should_update",
]
