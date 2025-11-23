"""Version fetching from various sources (GitHub, npm, custom APIs)."""

from typing import cast

from .http import fetch_json
from .nix import run_command


def fetch_github_latest_release(owner: str, repo: str) -> str:
    """Fetch the latest release version from GitHub.

    Args:
        owner: Repository owner
        repo: Repository name

    Returns:
        Latest release version (without 'v' prefix)

    """
    url = f"https://api.github.com/repos/{owner}/{repo}/releases/latest"
    data = fetch_json(url)
    if not isinstance(data, dict):
        msg = f"Expected dict from GitHub API, got {type(data)}"
        raise TypeError(msg)
    tag = cast("str", data["tag_name"])

    # Strip 'v' prefix if present
    return tag.lstrip("v")


def fetch_npm_version(package: str) -> str:
    """Fetch the latest version from npm registry.

    Args:
        package: npm package name

    Returns:
        Latest version

    """
    # Try using npm command first
    try:
        cmd = ["npm", "view", package, "version"]
        result = run_command(cmd)
        return result.stdout.strip()
    except (FileNotFoundError, OSError):
        # npm command not available, fallback to registry API
        url = f"https://registry.npmjs.org/{package}/latest"
        data = fetch_json(url)
        if not isinstance(data, dict):
            msg = f"Expected dict from npm registry, got {type(data)}"
            raise TypeError(msg) from None
        return cast("str", data["version"])


def compare_versions(v1: str, v2: str) -> int:
    """Compare two semantic versions.

    Args:
        v1: First version
        v2: Second version

    Returns:
        -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2

    """
    # Simple lexicographic comparison for now
    # Can be enhanced with proper semver parsing if needed
    if v1 == v2:
        return 0
    if v1 < v2:
        return -1
    return 1


def should_update(current: str, latest: str) -> bool:
    """Check if an update is needed.

    Args:
        current: Current version
        latest: Latest available version

    Returns:
        True if update is needed

    """
    return compare_versions(current, latest) < 0
