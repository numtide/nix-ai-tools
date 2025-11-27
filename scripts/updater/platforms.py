"""Multi-platform hash calculation utilities for Nix package updaters."""

from .hash import calculate_url_hash


def calculate_platform_hashes(
    url_template: str,
    platforms: dict[str, str],
    **format_kwargs: str,
) -> dict[str, str]:
    """Calculate hashes for each platform using URL template.

    Args:
        url_template: URL template with {platform} placeholder and optional other placeholders
        platforms: Dictionary mapping nix platform (e.g., "x86_64-linux") to platform-specific
                   value used in the URL (e.g., "linux/amd64", "aarch64.app.tar.gz")
        **format_kwargs: Additional format arguments for the URL template

    Returns:
        Dictionary mapping nix platform to hash

    Example:
        >>> platforms = {
        ...     "x86_64-linux": "linux-amd64",
        ...     "aarch64-darwin": "darwin-arm64",
        ... }
        >>> calculate_platform_hashes(
        ...     "https://example.com/releases/v{version}/app-{platform}.tar.gz",
        ...     platforms,
        ...     version="1.0.0",
        ... )
        {'x86_64-linux': 'sha256-...', 'aarch64-darwin': 'sha256-...'}

    """
    hashes = {}
    for nix_platform, platform_value in platforms.items():
        url = url_template.format(platform=platform_value, **format_kwargs)
        print(f"Fetching hash for {nix_platform}...")
        hashes[nix_platform] = calculate_url_hash(url)
    return hashes
