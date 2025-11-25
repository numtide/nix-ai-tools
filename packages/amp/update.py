#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for amp package."""

import json
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from urllib.request import urlretrieve

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import calculate_url_hash, fetch_npm_version, nix, should_update
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build


class AmpUpdater:
    """Custom updater for amp package with special package-lock.json handling."""

    def __init__(self) -> None:
        """Initialize the updater."""
        self.package = "amp"
        self.npm_package_name = "@sourcegraph/amp"
        self.script_dir = Path(__file__).parent
        self.version_file = self.script_dir / "version.json"

    def get_current_version(self) -> str:
        """Get current version from nix."""
        return nix.nix_eval(f".#{self.package}.version")

    def _read_version_data(self) -> dict[str, str]:
        """Read version data from JSON file."""
        data: dict[str, str] = json.loads(self.version_file.read_text())
        return data

    def _write_version_data(self, data: dict[str, str]) -> None:
        """Write version data to JSON file."""
        self.version_file.write_text(json.dumps(data, indent=2) + "\n")

    def _extract_package_lock(self, tarball_url: str) -> bool:
        """Extract package-lock.json from tarball or generate it.

        Args:
            tarball_url: URL of the tarball

        Returns:
            True if successful

        """
        print("Extracting package-lock.json from tarball...")
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            tarball_path = tmpdir_path / "amp.tgz"

            urlretrieve(tarball_url, tarball_path)

            # Extract with filter for security
            with tarfile.open(tarball_path, "r:gz") as tar:
                tar.extractall(tmpdir_path, filter="data")

            package_dir = tmpdir_path / "package"
            package_lock_src = package_dir / "package-lock.json"

            if package_lock_src.exists():
                package_lock_dst = self.script_dir / "package-lock.json"
                package_lock_dst.write_text(package_lock_src.read_text())
                print("Updated package-lock.json from tarball")
                return True

            return self._generate_package_lock(package_dir)

    def _generate_package_lock(self, package_dir: Path) -> bool:
        """Generate package-lock.json from package.json.

        Args:
            package_dir: Directory containing package.json

        Returns:
            True if successful

        """
        print("No package-lock.json in tarball, generating from package.json...")
        package_json = package_dir / "package.json"
        if not package_json.exists():
            print("ERROR: No package.json found in tarball!")
            return False

        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=package_dir,
            check=True,
        )

        new_lock = package_dir / "package-lock.json"
        if new_lock.exists():
            package_lock_dst = self.script_dir / "package-lock.json"
            package_lock_dst.write_text(new_lock.read_text())
            print("Generated and updated package-lock.json")
            return True

        print("ERROR: Failed to generate package-lock.json")
        return False

    def _update_npm_deps_hash(self) -> str:
        """Calculate the npmDeps hash by building with dummy hash.

        Returns:
            The new npmDeps hash

        """
        print("Calculating new npmDeps hash...")
        try:
            # Read current version data
            version_data = self._read_version_data()
            original_hash = version_data["npmDepsHash"]

            # Write dummy hash temporarily
            version_data["npmDepsHash"] = DUMMY_SHA256_HASH
            self._write_version_data(version_data)

            try:
                # Try to build, should fail with hash mismatch
                nix_build(f".#{self.package}", check=True)
                msg = "Build succeeded with dummy hash - unexpected"
                raise ValueError(msg)
            except NixCommandError as e:
                # Extract correct hash from error
                npm_deps_hash = extract_hash_from_build_error(e.args[0])
                if not npm_deps_hash:
                    # Restore original hash on failure
                    version_data["npmDepsHash"] = original_hash
                    self._write_version_data(version_data)
                    msg = f"Could not extract hash from build error:\n{e.args[0]}"
                    raise ValueError(msg) from e

                print(f"Updated npmDeps hash to {npm_deps_hash}")
                return npm_deps_hash
        except (OSError, ValueError, subprocess.CalledProcessError) as e:
            print(f"Warning: Could not update npmDeps hash: {e}")
            raise

    def update(self) -> bool:
        """Update the amp package."""
        current = self.get_current_version()
        latest = fetch_npm_version(self.npm_package_name)

        print(f"Current version: {current}")
        print(f"Latest version: {latest}")

        if not should_update(current, latest):
            return False

        print(f"Update available: {current} -> {latest}")

        tarball_url = (
            f"https://registry.npmjs.org/{self.npm_package_name}/-/amp-{latest}.tgz"
        )

        # Calculate source hash
        print("Calculating new source hash...")
        source_hash = calculate_url_hash(tarball_url)

        # Extract package-lock.json
        if not self._extract_package_lock(tarball_url):
            return False

        # Update version.json with new version and source hash first
        version_data = {
            "version": latest,
            "sourceHash": source_hash,
            "npmDepsHash": DUMMY_SHA256_HASH,  # Temporary, will be updated below
        }
        self._write_version_data(version_data)

        # Calculate and update npmDeps hash
        try:
            npm_deps_hash = self._update_npm_deps_hash()
            version_data["npmDepsHash"] = npm_deps_hash
            self._write_version_data(version_data)
        except (ValueError, NixCommandError) as e:
            print(f"Error updating npmDeps hash: {e}")
            return False

        return True


def main() -> None:
    """Update the amp package."""
    updater = AmpUpdater()
    if updater.update():
        print("Update complete for amp!")
    else:
        print("amp is already up-to-date!")


if __name__ == "__main__":
    main()
