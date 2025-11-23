#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for backlog-md package."""

import json
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    BaseUpdater,
    fetch_github_latest_release,
    get_node_modules_hash,
    nix,
    should_update,
)
from updater.hash import calculate_url_hash


class BacklogMdUpdater(BaseUpdater):
    """Custom updater for backlog-md using JSON sources file."""

    def __init__(self) -> None:
        """Initialize the backlog-md updater."""
        super().__init__("backlog-md")
        self.sources_file = Path(__file__).parent / "sources.json"

    def _write_sources(
        self,
        version: str,
        src_hash: str,
        node_modules_hash: str,
    ) -> None:
        """Write sources to sources.json.

        Args:
            version: Package version
            src_hash: Source hash
            node_modules_hash: Node modules hash

        """
        sources = {
            "version": version,
            "src_hash": src_hash,
            "node_modules_hash": node_modules_hash,
        }
        self.sources_file.write_text(json.dumps(sources, indent=2) + "\n")

    def update(self) -> bool:
        """Update the package by writing to sources.json."""
        current = self.get_current_version()
        latest = fetch_github_latest_release("MrLesk", "Backlog.md")

        if not should_update(current, latest):
            return False

        print(f"Updating backlog-md from {current} to {latest}")

        # Calculate source hash for fetchFromGitHub
        tag = f"v{latest}"
        url = f"https://github.com/MrLesk/Backlog.md/archive/{tag}.tar.gz"
        source_hash = calculate_url_hash(url, unpack=True)

        # Write temporary sources.json with dummy node_modules hash
        self._write_sources(
            latest,
            source_hash,
            "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        )

        # Calculate correct node_modules hash by building
        try:
            node_modules_hash = get_node_modules_hash("backlog-md", self.package_file)
        except (nix.NixCommandError, ValueError) as e:
            print(f"Error: Could not calculate node_modules hash: {e}")
            return False

        # Write final sources.json with all correct values
        self._write_sources(latest, source_hash, node_modules_hash)
        print(f"Updated sources.json with version {latest}")

        return True


def main() -> None:
    """Update the backlog-md package."""
    updater = BacklogMdUpdater()
    if updater.update():
        print("Update complete for backlog-md!")
    else:
        print("backlog-md is already up-to-date!")


if __name__ == "__main__":
    main()
