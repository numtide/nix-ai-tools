"""Hash calculation utilities for Nix packages."""

import re

from .nix import nix_prefetch_url, nix_store_prefetch_file

# Dummy hash used to trigger Nix build errors to extract correct hash
DUMMY_SHA256_HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="


def calculate_url_hash(url: str, *, unpack: bool = False) -> str:
    """Calculate hash for a URL.

    Args:
        url: URL to calculate hash for
        unpack: Whether to unpack the archive (use True for fetchzip packages)

    Returns:
        Hash in SRI format (sha256-...)

    """
    if unpack:
        # Use nix-prefetch-url --unpack for fetchzip packages
        return nix_prefetch_url(url, unpack=True)
    # Use nix store prefetch-file for regular fetchurl packages
    return nix_store_prefetch_file(url)


def extract_hash_from_build_error(error_output: str) -> str | None:
    """Extract the correct hash from a Nix build error message.

    Args:
        error_output: Error output from nix build command

    Returns:
        Extracted hash in SRI format, or None if not found

    """
    # Patterns match variations: "got: sha256-...", "got sha256-...", "actual: sha256-..."
    patterns = [
        r"got:\s+(sha256-[A-Za-z0-9+/=]+)",
        r"got\s+(sha256-[A-Za-z0-9+/=]+)",
        r"actual:\s+(sha256-[A-Za-z0-9+/=]+)",
    ]

    for pattern in patterns:
        match = re.search(pattern, error_output)
        if match:
            return match.group(1)

    return None
