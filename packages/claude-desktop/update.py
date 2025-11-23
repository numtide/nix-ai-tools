#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#p7zip --command python3

"""Update script for claude-desktop package.

This is a special case updater because:
- Downloads Windows .exe installers (not versioned URLs)
- Extracts version from the installer using 7z
- Updates hashes for both x86_64-linux and aarch64-linux
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    NixCommandError,
    calculate_url_hash,
    check_url_accessible,
    download_file,
    replace_in_file,
    update_version,
)

# Fixed URLs for Claude Desktop installers
X64_URL = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"
ARM64_URL = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/Claude-Setup-arm64.exe"


def extract_version_from_installer(installer_path: Path) -> str | None:
    """Extract version from Windows installer using 7z.

    Args:
        installer_path: Path to the .exe installer

    Returns:
        Version string if found, None otherwise

    """
    try:
        # Try method 1: List contents and look for version in NuGet package name
        result = subprocess.run(
            ["7z", "l", str(installer_path)],
            check=True,
            capture_output=True,
            text=True,
        )

        # Look for patterns like "AnthropicClaude-0.14.10"
        match = re.search(r"AnthropicClaude-(\d+\.\d+\.\d+)", result.stdout)
        if match:
            return match.group(1)

        # Try method 2: Extract and look for .nupkg files
        with tempfile.TemporaryDirectory() as temp_extract_dir:
            extract_path = Path(temp_extract_dir)
            subprocess.run(
                ["7z", "x", "-y", str(installer_path), f"-o{extract_path}"],
                check=True,
                capture_output=True,
            )

            # Find .nupkg files
            nupkg_files = list(extract_path.glob("AnthropicClaude-*.nupkg"))
            if nupkg_files:
                nupkg_name = nupkg_files[0].name
                match = re.search(r"AnthropicClaude-(\d+\.\d+\.\d+)", nupkg_name)
                if match:
                    return match.group(1)

    except subprocess.CalledProcessError:
        pass

    return None


def main() -> None:  # noqa: C901, PLR0912, PLR0915
    """Update claude-desktop package."""
    # Get script directory and package file path
    script_dir = Path(__file__).parent.resolve()
    package_file = script_dir / "package.nix"

    if not package_file.exists():
        print(f"ERROR: Package file not found: {package_file}")
        sys.exit(1)

    print("Checking Claude Desktop installers...")

    # Check both URLs are accessible
    print("Checking x64 installer...")
    if not check_url_accessible(X64_URL):
        print("ERROR: Cannot access x64 installer")
        sys.exit(1)
    print("✓ x64 installer is accessible")

    print("Checking arm64 installer...")
    if not check_url_accessible(ARM64_URL):
        print("ERROR: Cannot access arm64 installer")
        sys.exit(1)
    print("✓ arm64 installer is accessible")

    # Calculate hashes for both platforms
    print("\nCalculating hashes...")
    print("Calculating x64 hash...")
    try:
        x64_hash = calculate_url_hash(X64_URL)
        print(f"✓ x64 hash: {x64_hash}")
    except (NixCommandError, OSError) as e:
        print(f"ERROR: Failed to calculate x64 hash: {e}")
        sys.exit(1)

    print("Calculating arm64 hash...")
    try:
        arm64_hash = calculate_url_hash(ARM64_URL)
        print(f"✓ arm64 hash: {arm64_hash}")
    except (NixCommandError, OSError) as e:
        print(f"ERROR: Failed to calculate arm64 hash: {e}")
        sys.exit(1)

    # Try to extract version from installer
    print("\nAttempting to extract version from installer...")
    version = None

    with tempfile.TemporaryDirectory() as temp_dir:
        installer_path = Path(temp_dir) / "claude-setup.exe"

        # Download the x64 installer
        try:
            print("Downloading x64 installer...")
            download_file(X64_URL, installer_path)

            if installer_path.exists():
                version = extract_version_from_installer(installer_path)

        except (OSError, ValueError) as e:
            print(f"Warning: Failed to download installer for version detection: {e}")

    # Update the package file
    print("\nUpdating package.nix...")

    # Update version if detected
    if version:
        print(f"Detected version: {version}")

        # Read current version
        content = package_file.read_text()
        current_version_match = re.search(r'version\s*=\s*"([^"]+)"', content)

        if current_version_match:
            current_version = current_version_match.group(1)

            if current_version != version:
                print(f"Updating version from {current_version} to {version}")
                try:
                    update_version(package_file, current_version, version)
                except ValueError as e:
                    print(f"Warning: Could not update version: {e}")
            else:
                print("Version is already up to date")
        else:
            print("Warning: Could not find current version in package.nix")
    else:
        print("Could not detect version automatically")
        print("Note: Version number may need to be updated manually")
        print("Check https://github.com/aaddrick/claude-desktop-debian/releases")

    # Update hashes for both platforms
    try:
        # Update x64 hash
        # Pattern: x86_64-linux = fetchurl { url = "..."; hash = "sha256-..."; };
        pattern = r'(x86_64-linux\s*=\s*fetchurl\s*\{[^}]*hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"'
        replacement = rf'\1{x64_hash}"'
        replace_in_file(package_file, pattern, replacement, regex=True)
        print("✓ Updated x64 hash")

        # Update arm64 hash
        pattern = r'(aarch64-linux\s*=\s*fetchurl\s*\{[^}]*hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"'
        replacement = rf'\1{arm64_hash}"'
        replace_in_file(package_file, pattern, replacement, regex=True)
        print("✓ Updated arm64 hash")

    except (ValueError, OSError) as e:
        print(f"ERROR: Failed to update hashes in package.nix: {e}")
        sys.exit(1)

    print("\nHashes updated successfully!")

    if version:
        print(f"\n✓ Update complete! Version {version}")
    else:
        print("\n✓ Hashes updated! Please verify version manually if needed.")


if __name__ == "__main__":
    main()
