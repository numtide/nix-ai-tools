#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for catnip package."""

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
    """Update the catnip package."""
    updater = MultiPlatformUpdater(
        package="catnip",
        version_fetcher=lambda: fetch_github_latest_release("wandb", "catnip"),
        url_template="https://github.com/wandb/catnip/releases/download/v{version}/catnip_{version}_{platform}.tar.gz",
        platform_to_url_arch=make_platform_mapper(
            {"x86_64": "amd64", "aarch64": "arm64"},
            {"linux": "linux", "darwin": "darwin"},
            separator="_",
        ),
    )

    if updater.update():
        print("Update complete for catnip!")
    else:
        print("Already up-to-date!")


if __name__ == "__main__":
    main()
