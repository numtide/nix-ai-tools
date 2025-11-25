#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for cursor-agent package.

Cursor distributes agent via custom server with version embedded in install script.
Provides multi-platform tar.gz archives.
"""

import re
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    MultiPlatformUpdater,
    fetch_text,
    make_platform_mapper,
)


def fetch_cursor_agent_version() -> str:
    """Fetch the latest version by scraping the install script.

    Returns:
        Latest version string in format YYYY.MM.DD-hash

    """
    # Fetch the install script and extract version from download URLs
    install_script = fetch_text("https://cursor.com/install")

    # Look for pattern: downloads.cursor.com/lab/YYYY.MM.DD-hash
    match = re.search(
        r"downloads\.cursor\.com/lab/([0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]+)",
        install_script,
    )

    if not match:
        msg = "Could not extract version from install script"
        raise ValueError(msg)

    return match.group(1)


def main() -> None:
    """Update the cursor-agent package."""
    updater = MultiPlatformUpdater(
        package="cursor-agent",
        version_fetcher=fetch_cursor_agent_version,
        url_template="https://downloads.cursor.com/lab/{version}/{platform}/agent-cli-package.tar.gz",
        platform_to_url_arch=make_platform_mapper(
            {"x86_64": "x64", "aarch64": "arm64"},
            {"linux": "linux", "darwin": "darwin"},
            separator="/",
        ),
    )

    current_version = updater.get_current_version()

    if updater.update():
        new_version = updater.get_current_version()
        print(f"Updated cursor-agent from {current_version} to {new_version}")
    else:
        print(f"cursor-agent is already up to date at version {current_version}")


if __name__ == "__main__":
    main()
