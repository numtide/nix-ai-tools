"""Nix package updater library.

This library provides utilities for updating Nix packages in flakes,
including version fetching, hash calculation, and file modification.
"""

# Core updater classes
from .core import (
    BaseUpdater,
    MultiPlatformUpdater,
    NpmPackageUpdater,
    RustPackageUpdater,
    SimplePackageUpdater,
    UpdaterError,
)

# File operations
from .file_ops import (
    replace_in_file,
    update_hash,
    update_platform_hash,
    update_url,
    update_version,
)

# Hash utilities
from .hash import (
    calculate_url_hash,
    get_cargo_hash,
    get_node_modules_hash,
    get_npm_deps_hash,
)

# HTTP utilities
from .http import (
    check_url_accessible,
    download_file,
    fetch_json,
    fetch_text,
)

# Nix commands
from .nix import (
    NixCommandError,
    nix_eval,
    nix_prefetch_url,
    nix_store_prefetch_file,
    nix_update,
)

# Platforms
from .platforms import (
    ALL_PLATFORMS,
    Platform,
    make_platform_mapper,
)

# Version fetching
from .version import (
    fetch_github_latest_release,
    fetch_npm_version,
    should_update,
)

__all__ = [  # noqa: RUF022 - grouped by category for readability
    # Platforms
    "ALL_PLATFORMS",
    # Core
    "BaseUpdater",
    "MultiPlatformUpdater",
    # Nix
    "NixCommandError",
    "NpmPackageUpdater",
    "Platform",
    "RustPackageUpdater",
    "SimplePackageUpdater",
    "UpdaterError",
    # Hash
    "calculate_url_hash",
    "get_cargo_hash",
    # HTTP
    "check_url_accessible",
    "download_file",
    # Version
    "fetch_github_latest_release",
    "fetch_json",
    "fetch_npm_version",
    "fetch_text",
    "get_node_modules_hash",
    "get_npm_deps_hash",
    "make_platform_mapper",
    "nix_eval",
    "nix_prefetch_url",
    "nix_store_prefetch_file",
    "nix_update",
    # File operations
    "replace_in_file",
    "should_update",
    "update_hash",
    "update_platform_hash",
    "update_url",
    "update_version",
]
