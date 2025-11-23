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

from updater import (
    calculate_url_hash,
    fetch_npm_version,
    file_ops,
    get_npm_deps_hash,
    nix,
    should_update,
)


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

    def _update_npm_deps_hash(self) -> None:
        """Update the npmDeps hash in fetchNpmDeps block."""
        print("Calculating new npmDeps hash...")
        try:
            npm_deps_hash = get_npm_deps_hash(self.package, self.package_file)
            content = self.package_file.read_text()
            pattern = (
                r"(npmDeps = fetchNpmDeps \{[^}]*hash = \")sha256-[A-Za-z0-9+/=]+(\";)"
            )
            replacement = rf"\1{npm_deps_hash}\2"
            content = re.sub(pattern, replacement, content, flags=re.DOTALL)
            self.package_file.write_text(content)
        except (OSError, ValueError, subprocess.CalledProcessError) as e:
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
