"""Hash calculation utilities for Nix packages."""

import re
from pathlib import Path

from .file_ops import replace_in_file
from .nix import NixCommandError, nix_build, nix_prefetch_url, nix_store_prefetch_file

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


def get_hash_via_build(
    package: str,
    hash_attr: str,
    package_file: Path,
) -> str:
    """Get hash by setting dummy value and extracting from build error.

    This is useful for complex derivations where prefetching doesn't work
    (e.g., npmDeps, node_modules).

    Args:
        package: Package name (e.g., "amp")
        hash_attr: Attribute path in the nix file (e.g., "npmDepsHash")
        package_file: Path to the package.nix file

    Returns:
        Correct hash in SRI format

    Raises:
        ValueError: If hash cannot be extracted from build error

    """
    # Read current file content for backup
    original_content = package_file.read_text()

    try:
        # Find and replace the hash with dummy hash
        # Look for lines like: npmDepsHash = "sha256-...";
        pattern = rf'{hash_attr}\s*=\s*"sha256-[A-Za-z0-9+/=]+"'
        replacement = f'{hash_attr} = "{DUMMY_SHA256_HASH}"'

        if not re.search(pattern, original_content):
            msg = f"Could not find {hash_attr} pattern in {package_file}"
            raise ValueError(
                msg,
            )

        replace_in_file(
            package_file,
            pattern,
            replacement,
            regex=True,
        )

        # Try to build, which should fail with hash mismatch
        try:
            nix_build(f".#{package}", check=True)
            # If build succeeds, something went wrong
            msg = "Build succeeded with dummy hash - this shouldn't happen"
            raise ValueError(
                msg,
            )
        except NixCommandError as e:
            # Extract hash from error
            hash_value = extract_hash_from_build_error(e.args[0])
            if not hash_value:
                msg = f"Could not extract hash from build error:\n{e.args[0]}"
                raise ValueError(msg) from e

            return hash_value

    finally:
        # Restore original file content
        package_file.write_text(original_content)


def get_npm_deps_hash(
    package: str,
    package_file: Path,
) -> str:
    """Get npmDepsHash by building with dummy hash.

    Args:
        package: Package name
        package_file: Path to package.nix file

    Returns:
        Correct npmDepsHash

    """
    return get_hash_via_build(package, "npmDepsHash", package_file)


def get_node_modules_hash(
    package: str,
    package_file: Path,
) -> str:
    """Get node_modules outputHash by building with dummy hash.

    This is used for packages that use fetchBunDeps or similar.

    Args:
        package: str
        package_file: Path to package.nix file

    Returns:
        Correct outputHash for node_modules

    """
    return get_hash_via_build(package, "outputHash", package_file)


def get_cargo_hash(
    package: str,
    package_file: Path,
) -> str:
    """Get cargoHash by building with dummy hash.

    This is used for Rust packages that use buildRustPackage.

    Args:
        package: Package name
        package_file: Path to package.nix file

    Returns:
        Correct cargoHash

    """
    return get_hash_via_build(package, "cargoHash", package_file)
