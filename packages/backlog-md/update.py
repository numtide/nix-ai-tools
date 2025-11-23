#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for backlog-md package."""

import subprocess
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    SimplePackageUpdater,
    fetch_github_latest_release,
)
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build


class BacklogMdUpdater(SimplePackageUpdater):
    """Custom updater for backlog-md with node_modules hash handling."""

    # Second hash in the file is for node_modules
    NODE_MODULES_HASH_INDEX = 2

    def __init__(self) -> None:
        """Initialize the backlog-md updater."""
        super().__init__(
            package="backlog-md",
            version_fetcher=lambda: fetch_github_latest_release("MrLesk", "Backlog.md"),
            url_template="https://github.com/MrLesk/Backlog.md/archive/v{version}.tar.gz",
        )

    def _replace_nth_hash(self, content: str, n: int, new_hash: str) -> str:
        """Replace the nth occurrence of a hash in the content.

        Args:
            content: File content
            n: Which hash occurrence to replace (1-indexed)
            new_hash: New hash value

        Returns:
            Updated content

        """
        lines = content.split("\n")
        updated_lines = []
        hash_count = 0
        for line in lines:
            if 'hash = "sha256-' in line:
                hash_count += 1
                if hash_count == n:
                    indent = len(line) - len(line.lstrip())
                    updated_lines.append(f'{" " * indent}hash = "{new_hash}";')
                else:
                    updated_lines.append(line)
            else:
                updated_lines.append(line)
        return "\n".join(updated_lines)

    def _get_node_modules_hash(self, original_content: str) -> str:
        """Get node_modules hash by building with dummy hash.

        Args:
            original_content: Original file content to restore on error

        Returns:
            Correct node_modules hash

        """
        # Replace second hash with dummy
        content_with_dummy = self._replace_nth_hash(
            original_content, self.NODE_MODULES_HASH_INDEX, DUMMY_SHA256_HASH
        )
        self.package_file.write_text(content_with_dummy)

        try:
            # Build for x86_64-linux (use remote builders if needed)
            nix_build(f".#packages.x86_64-linux.{self.package}", check=True)
            msg = "Build succeeded with dummy hash - unexpected"
            raise ValueError(msg)
        except NixCommandError as e:
            # Extract hash from error
            node_modules_hash = extract_hash_from_build_error(e.args[0])
            if not node_modules_hash:
                msg = f"Could not extract hash from build error:\n{e.args[0]}"
                raise ValueError(msg) from e
            return node_modules_hash

    def update(self) -> bool:
        """Update the package including node_modules hash."""
        # First do the basic update (version and source hash)
        if not super().update():
            return False

        # Now update the node_modules hash
        print("Calculating new node_modules hash...")
        original_content = self.package_file.read_text()

        try:
            node_modules_hash = self._get_node_modules_hash(original_content)
            # Update with correct hash
            updated_content = self._replace_nth_hash(
                original_content, self.NODE_MODULES_HASH_INDEX, node_modules_hash
            )
            self.package_file.write_text(updated_content)
        except (OSError, ValueError, subprocess.CalledProcessError) as e:
            print(f"Warning: Could not update node_modules hash: {e}")

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
