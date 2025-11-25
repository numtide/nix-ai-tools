#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for claude-code package."""

import subprocess
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    NpmPackageUpdater,
    fetch_npm_version,
    should_update,
)


class ClaudeCodeUpdater(NpmPackageUpdater):
    """Custom updater for claude-code that handles package-lock.json generation."""

    def update(self) -> bool:
        """Update the package with package-lock.json generation."""
        current = self.get_current_version()
        latest = fetch_npm_version(self.npm_package_name)

        print(f"Current version: {current}")
        print(f"Latest version: {latest}")

        if not should_update(current, latest):
            return False

        print(f"Update available: {current} -> {latest}")

        # Generate package-lock.json in the package directory
        script_dir = Path(__file__).parent
        package_json_path = script_dir / "package.json"
        script_dir / "package-lock.json"

        # Clean up any existing package.json (temporary)
        package_json_created = False
        if not package_json_path.exists():
            package_json_created = True

        try:
            # Generate package-lock.json
            print("Updating package-lock.json...")
            subprocess.run(
                [
                    "npm",
                    "i",
                    "--package-lock-only",
                    f"{self.npm_package_name}@{latest}",
                ],
                cwd=script_dir,
                check=True,
            )

            # Now do the standard update
            return super().update()

        finally:
            # Clean up temporary package.json if we created it
            if package_json_created and package_json_path.exists():
                package_json_path.unlink()


def main() -> None:
    """Update the claude-code package."""
    updater = ClaudeCodeUpdater(
        package="claude-code",
        npm_package_name="@anthropic-ai/claude-code",
        has_npm_deps_hash=True,
        unpack=True,  # Uses fetchzip which requires unpacked hash
    )
    if updater.update():
        print("Update complete for claude-code!")
    else:
        print("claude-code is already up-to-date!")


if __name__ == "__main__":
    main()
