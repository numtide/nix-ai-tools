"""File manipulation utilities for updating Nix package files."""

import re
from pathlib import Path


def replace_in_file(
    file_path: Path,
    old: str,
    new: str,
    *,
    regex: bool = False,
    count: int = -1,
) -> bool:
    """Replace text in a file.

    Args:
        file_path: Path to the file to modify
        old: Text or pattern to replace
        new: Replacement text
        regex: Whether to treat 'old' as a regex pattern
        count: Maximum number of replacements (-1 for first match, 0 for all)

    Returns:
        True if any replacements were made

    """
    content = file_path.read_text()

    if regex:
        # Convert count: -1 means "first match", 0 means "all matches"
        # re.sub uses: 0 for "all", 1+ for "that many"
        regex_count = 1 if count == -1 else (0 if count == 0 else count)
        new_content = re.sub(old, new, content, count=regex_count)
    else:
        new_content = content.replace(old, new, count if count >= 0 else -1)

    if new_content != content:
        file_path.write_text(new_content)
        return True

    return False


def update_version(file_path: Path, old_version: str, new_version: str) -> None:
    """Update version string in a file.

    Args:
        file_path: Path to the package file
        old_version: Current version
        new_version: New version

    """
    # Matches patterns like: version = "1.2.3";
    pattern = rf'version\s*=\s*"{re.escape(old_version)}"'
    replacement = f'version = "{new_version}"'

    if not replace_in_file(file_path, pattern, replacement, regex=True):
        msg = f'Could not find version = "{old_version}" in {file_path}'
        raise ValueError(
            msg,
        )


def update_hash(
    file_path: Path,
    attr_name: str,
    new_hash: str,
    old_hash: str | None = None,
) -> None:
    """Update a hash attribute in a file.

    Args:
        file_path: Path to the package file
        attr_name: Name of the hash attribute (e.g., "hash", "npmDepsHash")
        new_hash: New hash value
        old_hash: Old hash value (if known, for exact replacement)

    """
    if old_hash:
        # Exact replacement
        pattern = rf'{attr_name}\s*=\s*"{re.escape(old_hash)}"'
        replacement = f'{attr_name} = "{new_hash}"'
    else:
        # Replace any hash value for this attribute
        pattern = rf'({attr_name}\s*=\s*")sha256-[A-Za-z0-9+/=]+"'
        replacement = rf'\1{new_hash}"'

    if not replace_in_file(file_path, pattern, replacement, regex=True):
        msg = f"Could not find {attr_name} pattern in {file_path}"
        raise ValueError(
            msg,
        )


def update_platform_hash(
    file_path: Path,
    platform: str,
    new_hash: str,
) -> None:
    """Update hash for a specific platform in a multi-platform package.

    Args:
        file_path: Path to the package file
        platform: Platform name (e.g., "x86_64-linux")
        new_hash: New hash value

    """
    content = file_path.read_text()

    # Pattern 1: Direct assignment (e.g., x86_64-linux = "sha256-...")
    # Pattern 2: Quoted platform (e.g., "x86_64-linux" = "sha256-...")
    # Pattern 3: Nested structure (e.g., x86_64-linux = { ... hash = "sha256-..."; })
    # Pattern 4: mkNativeBinary helper with system = "platform"
    patterns = [
        # Direct assignment: platform = "sha256-...";
        (
            rf'("{re.escape(platform)}"\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
            rf'\1{new_hash}"',
        ),
        (
            rf'({re.escape(platform)}\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
            rf'\1{new_hash}"',
        ),
        # Nested structure: platform = { ... hash = "sha256-..."; }
        # Use .+? instead of [^}]*? to handle ${version} interpolation
        (
            rf'({re.escape(platform)}\s*=\s*\{{.+?hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
            rf'\1{new_hash}"',
        ),
        # With fetchurl: platform = fetchurl { ... hash = "sha256-..."; }
        (
            rf'({re.escape(platform)}\s*=\s*fetchurl\s*\{{.+?hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
            rf'\1{new_hash}"',
        ),
        # mkNativeBinary with system = "platform"; ... hash = "sha256-...";
        # This handles the ECA package pattern
        (
            rf'(system\s*=\s*"{re.escape(platform)}";\s*.+?hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
            rf'\1{new_hash}"',
        ),
    ]

    for pattern, replacement in patterns:
        # Use count=1 to replace only the first match, preventing global replacements
        # This ensures we only update the hash for the specific platform section
        new_content = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)
        if new_content != content:
            file_path.write_text(new_content)
            return

    msg = f"Could not find platform hash pattern for {platform} in {file_path}"
    raise ValueError(
        msg,
    )


def update_url(
    file_path: Path,
    old_version: str,
    new_version: str,
) -> None:
    """Update version in URLs.

    Args:
        file_path: Path to the package file
        old_version: Current version
        new_version: New version

    """
    # Replace version in URLs (v{version} and just {version})
    patterns_replacements = [
        (rf"v{re.escape(old_version)}", f"v{new_version}"),
        (rf"/{re.escape(old_version)}/", f"/{new_version}/"),
        (rf"-{re.escape(old_version)}\.", f"-{new_version}."),
    ]

    for pattern, replacement in patterns_replacements:
        replace_in_file(file_path, pattern, replacement, regex=True)
