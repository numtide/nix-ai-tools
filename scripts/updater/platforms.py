"""Multi-platform hash calculation utilities for Nix package updaters."""

from concurrent.futures import ThreadPoolExecutor, as_completed

from .hash import calculate_url_hash


def calculate_platform_hashes(
    url_template: str,
    platforms: dict[str, str],
    **format_kwargs: str,
) -> dict[str, str]:
    """Calculate hashes for each platform using URL template.

    Fetches hashes in parallel using a thread pool for faster execution.

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

    def fetch_hash(nix_platform: str, platform_value: str) -> tuple[str, str]:
        url = url_template.format(platform=platform_value, **format_kwargs)
        hash_value = calculate_url_hash(url)
        print(f"Fetched hash for {nix_platform}")
        return nix_platform, hash_value

    print(f"Fetching hashes for {len(platforms)} platforms in parallel...")
    hashes = {}
    with ThreadPoolExecutor(max_workers=len(platforms)) as executor:
        futures = {
            executor.submit(fetch_hash, nix_platform, platform_value): nix_platform
            for nix_platform, platform_value in platforms.items()
        }
        for future in as_completed(futures):
            nix_platform, hash_value = future.result()
            hashes[nix_platform] = hash_value

    return hashes
