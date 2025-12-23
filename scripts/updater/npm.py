"""NPM package utilities for Nix package updates."""

import os
import subprocess
import tarfile
import tempfile
from pathlib import Path
from urllib.request import urlretrieve


def extract_or_generate_lockfile(
    tarball_url: str,
    output_path: Path,
    *,
    env: dict[str, str] | None = None,
) -> bool:
    """Extract package-lock.json from npm tarball or generate it.

    Downloads the npm tarball, checks if it contains a package-lock.json,
    and either extracts it or generates one using npm.

    Args:
        tarball_url: URL to the npm package tarball
        output_path: Path where package-lock.json should be written
        env: Optional environment variables to pass to npm install

    Returns:
        True if lockfile was successfully extracted or generated, False otherwise

    """
    print("Extracting/generating package-lock.json from tarball...")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        tarball_path = tmpdir_path / "package.tgz"
        urlretrieve(tarball_url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir_path, filter="data")

        package_dir = tmpdir_path / "package"
        package_lock_src = package_dir / "package-lock.json"

        # Check if lockfile exists in tarball
        if package_lock_src.exists():
            output_path.write_text(package_lock_src.read_text())
            print("Updated package-lock.json from tarball")
            return True

        # Generate if not in tarball
        print("No package-lock.json in tarball, generating...")
        if not (package_dir / "package.json").exists():
            print("ERROR: No package.json found!")
            return False

        run_env = {**os.environ, **(env or {})}

        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=package_dir,
            env=run_env,
            check=True,
        )

        new_lock = package_dir / "package-lock.json"
        if new_lock.exists():
            output_path.write_text(new_lock.read_text())
            print("Generated package-lock.json")
            return True

        print("ERROR: Failed to generate package-lock.json")
        return False
