#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for droid package.

Droid is distributed by Factory AI with separate binaries for droid itself
and ripgrep. Each has different URL patterns and must be updated independently.
"""

import re
import sys
from pathlib import Path
from typing import ClassVar

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    BaseUpdater,
    Platform,
    calculate_url_hash,
    fetch_text,
    nix_eval,
    replace_in_file,
    update_version,
)


def fetch_droid_version() -> str:
    """Fetch the latest version from Factory AI's install script.

    Returns:
        Latest version string

    """
    # Extract version from the official installation script
    script_content = fetch_text("https://app.factory.ai/cli")

    # Look for VER="x.y.z"
    match = re.search(r'VER="([^"]+)"', script_content)

    if not match:
        msg = "Could not extract version from install script"
        raise ValueError(msg)

    return match.group(1)


class DroidUpdater(BaseUpdater):
    """Custom updater for droid package with dual binary sources."""

    # Only these platforms are supported (no x86_64-darwin)
    PLATFORMS: ClassVar[list[Platform]] = [
        Platform.X86_64_LINUX,
        Platform.AARCH64_LINUX,
        Platform.AARCH64_DARWIN,
    ]

    def __init__(self) -> None:
        """Initialize the droid updater."""
        super().__init__("droid")

    def update(self) -> bool:
        """Update droid package.

        Returns:
            True if update was performed

        """
        current_version = self.get_current_version()
        latest_version = fetch_droid_version()

        if current_version == latest_version:
            print(f"Already at version {current_version}")
            return False

        print(f"Updating from {current_version} to {latest_version}")

        # Update version in file
        update_version(self.package_file, current_version, latest_version)

        # Update hashes for both droid and ripgrep binaries
        self._update_droid_hashes(latest_version)
        self._update_ripgrep_hashes()

        return True

    def _update_droid_hashes(self, version: str) -> None:
        """Update hashes for droid binaries.

        Args:
            version: Version to update to

        """
        for platform in self.PLATFORMS:
            url_arch = self._platform_to_url_arch(platform)
            url = f"https://downloads.factory.ai/factory-cli/releases/{version}/{url_arch}/droid"

            print(f"Fetching hash for droid {platform.value}...")
            try:
                new_hash = calculate_url_hash(url)
                self._update_platform_hash_in_section("sources", platform, new_hash)
            except (OSError, ValueError) as e:
                print(
                    f"Warning: Failed to update {platform.value}: {e}",
                    file=sys.stderr,
                )

    def _update_ripgrep_hashes(self) -> None:
        """Update hashes for ripgrep binaries (no version in URL)."""
        for platform in self.PLATFORMS:
            url_arch = self._platform_to_url_arch(platform)
            url = f"https://downloads.factory.ai/ripgrep/{url_arch}/rg"

            print(f"Fetching hash for ripgrep {platform.value}...")
            try:
                new_hash = calculate_url_hash(url)
                self._update_platform_hash_in_section("rgSources", platform, new_hash)
            except (OSError, ValueError) as e:
                print(
                    f"Warning: Failed to update ripgrep {platform.value}: {e}",
                    file=sys.stderr,
                )

    def _platform_to_url_arch(self, platform: Platform) -> str:
        """Convert Platform to Factory AI's URL path format.

        Args:
            platform: Platform enum value

        Returns:
            URL path (e.g., "linux/x64", "darwin/arm64")

        """
        mapping = {
            "x86_64-linux": "linux/x64",
            "aarch64-linux": "linux/arm64",
            "aarch64-darwin": "darwin/arm64",
        }
        return mapping[platform.value]

    def _update_platform_hash_in_section(
        self,
        section: str,
        platform: Platform,
        new_hash: str,
    ) -> None:
        """Update hash for a specific platform in a specific section.

        The droid package has two sections: 'sources' and 'rgSources'.
        We need to update the hash in the correct section.

        Args:
            section: Section name ("sources" or "rgSources")
            platform: Platform to update
            new_hash: New hash value

        """
        # Get the old hash from the package
        attr = f".#droid.passthru.{section}.{platform.value}.hash"
        old_hash = nix_eval(attr)

        # Replace the old hash with the new one
        # This is more precise than pattern matching since droid has two sets of hashes
        if not replace_in_file(
            self.package_file,
            old_hash,
            new_hash,
        ):
            msg = f"Could not find hash {old_hash} for {section}.{platform.value}"
            raise ValueError(msg)


def main() -> None:
    """Update the droid package."""
    updater = DroidUpdater()

    if updater.update():
        print(f"\nUpdated droid to version {updater.get_current_version()}")
    else:
        print("droid is already up to date")


if __name__ == "__main__":
    main()
