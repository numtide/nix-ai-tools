#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for forge package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    MultiPlatformUpdater,
    fetch_github_latest_release,
)


def main() -> None:
    """Update the forge package."""
    updater = MultiPlatformUpdater(
        package="forge",
        version_fetcher=lambda: fetch_github_latest_release("antinomyhq", "forge"),
        url_template="https://github.com/antinomyhq/forge/releases/download/v{version}/forge-{platform}",
        platform_to_url_arch=lambda p: p.to_rust_target(),
    )

    if updater.update():
        print("Update complete for Forge!")
    else:
        print("Already up-to-date!")


if __name__ == "__main__":
    main()
