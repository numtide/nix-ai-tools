#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for coderabbit-cli package.

CodeRabbit provides version info at a custom endpoint and distributes
platform-specific zip files.
"""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    MultiPlatformUpdater,
    fetch_text,
    make_platform_mapper,
)


def fetch_coderabbit_version() -> str:
    """Fetch the latest version from CodeRabbit's VERSION endpoint.

    Returns:
        Latest version string

    """
    url = "https://cli.coderabbit.ai/releases/latest/VERSION"
    return fetch_text(url).strip()


def main() -> None:
    """Update the coderabbit-cli package."""
    updater = MultiPlatformUpdater(
        package="coderabbit-cli",
        version_fetcher=fetch_coderabbit_version,
        url_template="https://cli.coderabbit.ai/releases/{version}/coderabbit-{platform}.zip",
        platform_to_url_arch=make_platform_mapper(
            {"x86_64": "x64", "aarch64": "arm64"},
            {"linux": "linux", "darwin": "darwin"},
        ),
    )

    if updater.update():
        print(f"Updated coderabbit-cli to version {updater.get_current_version()}")
    else:
        print("coderabbit-cli is already up to date")


if __name__ == "__main__":
    main()
