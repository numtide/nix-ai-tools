#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex package."""

import re
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import RustPackageUpdater, fetch_github_latest_release


def fetch_codex_version() -> str:
    """Fetch latest codex version from GitHub releases.

    Returns:
        Latest version matching rust-v* pattern

    """
    # Get the latest release tag (e.g., "rust-v0.63.0")
    tag = fetch_github_latest_release("openai", "codex")

    # Extract version from tag (rust-v0.63.0 -> 0.63.0)
    match = re.match(r"^rust-v(.+)$", tag)
    if match:
        return match.group(1)

    # If no match, return the tag as-is
    return tag


def main() -> None:
    """Update the codex package."""
    updater = RustPackageUpdater(
        package="codex",
        version_fetcher=fetch_codex_version,
        repo_owner="openai",
        repo_name="codex",
        tag_template="rust-v{version}",
    )

    if updater.update():
        print("Update complete for codex!")
    else:
        print("codex is already up-to-date!")


if __name__ == "__main__":
    main()
