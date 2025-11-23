#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for eca package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    MultiPlatformUpdater,
    fetch_github_latest_release,
    make_platform_mapper,
)


def main() -> None:
    """Update the eca package."""
    updater = MultiPlatformUpdater(
        package="eca",
        version_fetcher=lambda: fetch_github_latest_release(
            "editor-code-assistant",
            "eca",
        ),
        url_template="https://github.com/editor-code-assistant/eca/releases/download/{version}/eca-native-{platform}.zip",
        platform_to_url_arch=make_platform_mapper(
            {"x86_64": "amd64", "aarch64": "aarch64"},
            {"linux": "linux", "darwin": "macos"},
        ),
    )

    if updater.update():
        print("Update complete for eca!")
    else:
        print("Already up-to-date!")


if __name__ == "__main__":
    main()
