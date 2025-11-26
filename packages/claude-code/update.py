#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for claude-code package.

Claude Code provides version info at a stable endpoint and distributes
platform-specific binaries with checksums in manifest.json.
"""

import base64
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    BaseUpdater,
    fetch_json,
    fetch_text,
    should_update,
    update_platform_hash,
    update_version,
)

BASE_URL = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Platform mappings (Nix platform -> manifest platform)
PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}


def fetch_claude_version() -> str:
    """Fetch the latest version from Claude Code's stable endpoint.

    Returns:
        Latest version string

    """
    url = f"{BASE_URL}/stable"
    return fetch_text(url).strip()


def fetch_manifest(version: str) -> dict[str, object]:
    """Fetch the manifest.json for a specific version.

    Args:
        version: Version string

    Returns:
        Manifest dictionary with platform checksums

    """
    url = f"{BASE_URL}/{version}/manifest.json"
    result = fetch_json(url)
    if not isinstance(result, dict):
        msg = f"Expected dict from manifest.json, got {type(result)}"
        raise TypeError(msg)
    return result


def sha256_hex_to_sri(sha256_hex: str) -> str:
    """Convert a SHA256 hex hash to SRI format.

    Args:
        sha256_hex: SHA256 hash in hex format

    Returns:
        SRI format hash (sha256-base64)

    """
    hash_bytes = bytes.fromhex(sha256_hex)
    b64_hash = base64.b64encode(hash_bytes).decode("ascii")
    return f"sha256-{b64_hash}"


class ClaudeCodeUpdater(BaseUpdater):
    """Custom updater for claude-code that fetches hashes from manifest.json."""

    def update(self) -> bool:
        """Update the package with hashes from manifest.json.

        Returns:
            True if update was performed, False if already up-to-date

        """
        current = self.get_current_version()
        latest = fetch_claude_version()

        print(f"Current version: {current}")
        print(f"Latest version: {latest}")

        if not should_update(current, latest):
            return False

        print(f"Updating claude-code from {current} to {latest}")

        # Update version first
        update_version(self.package_file, current, latest)

        # Fetch manifest and extract hashes
        print("Fetching manifest.json...")
        manifest = fetch_manifest(latest)

        # Update hashes for each platform
        platforms_data = manifest["platforms"]
        if not isinstance(platforms_data, dict):
            msg = "Expected 'platforms' to be a dict"
            raise TypeError(msg)

        for nix_platform, manifest_platform in PLATFORMS.items():
            platform_info = platforms_data[manifest_platform]
            if not isinstance(platform_info, dict):
                msg = f"Expected platform info to be a dict, got {type(platform_info)}"
                raise TypeError(msg)
            checksum = platform_info["checksum"]
            if not isinstance(checksum, str):
                msg = f"Expected checksum to be a str, got {type(checksum)}"
                raise TypeError(msg)
            sri_hash = sha256_hex_to_sri(checksum)
            update_platform_hash(self.package_file, nix_platform, sri_hash)
            print(f"  {nix_platform}: {sri_hash}")

        return True


def main() -> None:
    """Update the claude-code package."""
    updater = ClaudeCodeUpdater(package="claude-code")

    if updater.update():
        print("Update complete for claude-code!")
    else:
        print("claude-code is already up-to-date!")


if __name__ == "__main__":
    main()
