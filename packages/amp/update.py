#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for amp package."""

import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from urllib.request import urlretrieve

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

import contextlib

from updater import (
    calculate_url_hash,
    fetch_npm_version,
    file_ops,
    nix,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_build


class AmpUpdater:
    """Custom updater for amp package with special package-lock.json handling."""

    def __init__(self) -> None:
        """Initialize the updater."""
        self.package = "amp"
        self.npm_package_name = "@sourcegraph/amp"
        self.script_dir = Path(__file__).parent
        self.package_file = self.script_dir / "package.nix"

    def get_current_version(self) -> str:
        """Get current version from nix."""
        return nix.nix_eval(f".#{self.package}.version")

    def _update_source_hash(self, tarball_url: str) -> str:
        """Update the source hash for the tarball.

        Args:
            tarball_url: URL of the tarball

        Returns:
            The new source hash

        """
        print("Calculating new source hash...")
        new_source_hash = calculate_url_hash(tarball_url)

        content = self.package_file.read_text()

        # Update the URL
        content = re.sub(
            r'url = "https://registry\.npmjs\.org/@sourcegraph/amp/-/amp-[^"]+\.tgz";',
            f'url = "{tarball_url}";',
            content,
        )

        # Update the first hash (fetchurl hash) that comes after the url line
        lines = content.split("\n")
        updated_lines = []
        found_url = False
        for line in lines:
            if 'url = "https://registry.npmjs.org/@sourcegraph/amp' in line:
                found_url = True
                updated_lines.append(line)
            elif found_url and "hash =" in line:
                updated_lines.append(f'        hash = "{new_source_hash}";')
                found_url = False
            else:
                updated_lines.append(line)

        self.package_file.write_text("\n".join(updated_lines))
        return new_source_hash

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

    def _validate_hash_replacement(self, content: str, dummy_content: str) -> None:
        """Validate that hash replacement was successful.

        Args:
            content: Original content
            dummy_content: Content after hash replacement

        Raises:
            ValueError: If hash pattern was not found

        """
        if dummy_content == content:
            msg = "Could not find npmDeps hash pattern in package.nix"
            raise ValueError(msg)

    def _update_npm_deps_hash(self) -> None:
        """Update the npmDeps hash in fetchNpmDeps block."""
        print("Calculating new npmDeps hash...")
        try:
            # Read current content
            content = self.package_file.read_text()

            # Replace hash with dummy to trigger build error
            pattern = (
                r"(npmDeps = fetchNpmDeps \{[^}]*hash = \")sha256-[A-Za-z0-9+/=]+(\";)"
            )
            dummy_content = re.sub(
                pattern, rf"\1{DUMMY_SHA256_HASH}\2", content, flags=re.DOTALL
            )

            self._validate_hash_replacement(content, dummy_content)

            # Write dummy hash temporarily
            self.package_file.write_text(dummy_content)

            try:
                # Try to build, should fail with hash mismatch
                nix_build(f".#{self.package}", check=True)
                msg = "Build succeeded with dummy hash - unexpected"
                raise ValueError(msg)
            except NixCommandError as e:
                # Extract correct hash from error
                npm_deps_hash = extract_hash_from_build_error(e.args[0])
                if not npm_deps_hash:
                    msg = f"Could not extract hash from build error:\n{e.args[0]}"
                    raise ValueError(msg) from e

                # Update with correct hash
                final_content = re.sub(
                    pattern, rf"\1{npm_deps_hash}\2", content, flags=re.DOTALL
                )
                self.package_file.write_text(final_content)
                print(f"Updated npmDeps hash to {npm_deps_hash}")
        except (OSError, ValueError, subprocess.CalledProcessError) as e:
            # Restore original content on any error
            with contextlib.suppress(Exception):
                self.package_file.write_text(content)
            print(f"Warning: Could not update npmDeps hash: {e}")

    def update(self) -> bool:
        """Update the amp package."""
        current = self.get_current_version()
        latest = fetch_npm_version(self.npm_package_name)

        print(f"Current version: {current}")
        print(f"Latest version: {latest}")

        if not should_update(current, latest):
            return False

        print(f"Update available: {current} -> {latest}")

        file_ops.update_version(self.package_file, current, latest)

        tarball_url = (
            f"https://registry.npmjs.org/{self.npm_package_name}/-/amp-{latest}.tgz"
        )

        self._update_source_hash(tarball_url)

        if not self._extract_package_lock(tarball_url):
            return False

        self._update_npm_deps_hash()

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
