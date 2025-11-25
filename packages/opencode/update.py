#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for opencode package."""

import sys
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    BaseUpdater,
    fetch_github_latest_release,
    file_ops,
    nix,
    should_update,
)
from updater import (
    hash as hash_utils,
)


class OpencodeUpdater(BaseUpdater):
    """Custom updater for opencode with node_modules hash."""

    def __init__(self) -> None:
        """Initialize the updater."""
        super().__init__("opencode")

    def update(self) -> bool:
        """Update the opencode package."""
        current = self.get_current_version()
        latest = fetch_github_latest_release("sst", "opencode")

        if not should_update(current, latest):
            return False

        print(f"Updating opencode from {current} to {latest}")

        # Update version
        file_ops.update_version(self.package_file, current, latest)
        file_ops.update_url(self.package_file, current, latest)

        # Update source hash
        tag = f"v{latest}"
        url = f"https://github.com/sst/opencode/archive/refs/tags/{tag}.tar.gz"
        try:
            # fetchFromGitHub unpacks, so use unpack=True
            source_hash = hash_utils.calculate_url_hash(url, unpack=True)
            file_ops.update_hash(self.package_file, "hash", source_hash)
        except (nix.NixCommandError, ValueError) as e:
            print(f"Warning: Could not update source hash: {e}")

        # Update node_modules hash
        try:
            node_modules_hash = hash_utils.get_node_modules_hash(
                "opencode",
                self.package_file,
            )
            file_ops.update_hash(self.package_file, "outputHash", node_modules_hash)
        except (nix.NixCommandError, ValueError) as e:
            print(f"Warning: Could not update node_modules hash: {e}")

        return True


def main() -> None:
    """Update the opencode package."""
    updater = OpencodeUpdater()
    if updater.update():
        print("Update complete for opencode!")
    else:
        print("opencode is already up-to-date!")


if __name__ == "__main__":
    main()
