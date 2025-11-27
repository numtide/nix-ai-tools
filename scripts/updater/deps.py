"""Dependency hash calculation utilities for Nix package updaters.

This module provides utilities for calculating dependency hashes
(cargoHash, vendorHash, npmDepsHash, outputHash) using the
dummy-hash-and-build pattern.
"""

from pathlib import Path
from typing import Any

from .hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from .hashes_file import save_hashes
from .nix import NixCommandError, nix_build


def calculate_dependency_hash(
    package_attr: str,
    hash_key: str,
    hashes_file: Path,
    data: dict[str, Any],
) -> str:
    """Calculate dependency hash by building with dummy hash and extracting from error.

    This function:
    1. Saves the current hash value
    2. Writes a dummy hash to hashes.json
    3. Triggers a nix build (which will fail)
    4. Extracts the correct hash from the build error
    5. Restores original hash on failure

    Args:
        package_attr: Nix package attribute (e.g., ".#codex", ".#claude-code")
        hash_key: Key in data dict for the hash (e.g., "cargoHash", "vendorHash")
        hashes_file: Path to hashes.json file
        data: Dictionary containing package data

    Returns:
        Calculated hash in SRI format

    Raises:
        ValueError: If hash cannot be extracted from build error

    """
    print(f"Calculating {hash_key}...")
    original_hash = data[hash_key]

    # Write dummy hash
    data[hash_key] = DUMMY_SHA256_HASH
    save_hashes(hashes_file, data)

    try:
        nix_build(package_attr, check=True)
        msg = "Build succeeded with dummy hash - unexpected"
        raise ValueError(msg)
    except NixCommandError as e:
        dep_hash = extract_hash_from_build_error(e.args[0])
        if not dep_hash:
            # Restore original hash
            data[hash_key] = original_hash
            save_hashes(hashes_file, data)
            msg = f"Could not extract hash from build error:\n{e.args[0]}"
            raise ValueError(msg) from e
        return dep_hash
