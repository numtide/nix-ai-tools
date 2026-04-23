#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for Goose frontend packages and shared backend artifacts."""

import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from urllib.request import urlretrieve

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_github_latest_release,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH

PKG_DIR = Path(__file__).parent
HASHES_FILE = PKG_DIR / "hashes.json"
PACKAGE_LOCK = PKG_DIR / "package-lock.json"

GITHUB_OWNER = "aaif-goose"
GITHUB_REPO = "goose"
NPM_PACKAGE = "@aaif/goose"


def cli_binary_url(version: str) -> str:
    return f"https://github.com/{GITHUB_OWNER}/{GITHUB_REPO}/releases/download/v{version}/goose-x86_64-unknown-linux-gnu.tar.gz"


def desktop_deb_url(version: str) -> str:
    return f"https://github.com/{GITHUB_OWNER}/{GITHUB_REPO}/releases/download/v{version}/goose_{version}_amd64.deb"


def cli_npm_url(version: str) -> str:
    return f"https://registry.npmjs.org/@aaif/goose/-/goose-{version}.tgz"


def regenerate_lockfile(version: str) -> None:
    """Regenerate package-lock.json from the npm tarball with Nix-safe patching."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        tarball_path = tmpdir_path / "goose.tgz"
        urlretrieve(cli_npm_url(version), tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir_path, filter="data")

        package_dir = tmpdir_path / "package"
        package_json = package_dir / "package.json"
        data = json.loads(package_json.read_text())
        data.pop("optionalDependencies", None)
        data.setdefault("scripts", {})["postinstall"] = ""
        package_json.write_text(json.dumps(data, indent=2) + "\n")

        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=package_dir,
            check=True,
        )

        shutil.copy2(package_dir / "package-lock.json", PACKAGE_LOCK)


def main() -> None:
    """Update Goose package metadata and derived hashes."""
    data = load_hashes(HASHES_FILE)
    current_desktop = data["desktopVersion"]
    current_cli = data["cliVersion"]
    latest_desktop = fetch_github_latest_release(GITHUB_OWNER, GITHUB_REPO)
    latest_cli = fetch_npm_version(NPM_PACKAGE)

    print(
        f"Desktop current={current_desktop} latest={latest_desktop}; "
        f"CLI current={current_cli} latest={latest_cli}"
    )

    desktop_changed = should_update(current_desktop, latest_desktop)
    cli_changed = should_update(current_cli, latest_cli)
    if not desktop_changed and not cli_changed:
        print("Already up to date")
        return

    new_desktop = latest_desktop if desktop_changed else current_desktop
    new_cli = latest_cli if cli_changed else current_cli

    print("Updating hashes...")
    data.update(
        {
            "desktopVersion": new_desktop,
            "cliVersion": new_cli,
            "cliBinaryHash": calculate_url_hash(cli_binary_url(new_desktop)),
            "desktopDebHash": calculate_url_hash(desktop_deb_url(new_desktop)),
            "cliNpmHash": calculate_url_hash(cli_npm_url(new_cli)),
            "npmDepsHash": DUMMY_SHA256_HASH,
        }
    )
    save_hashes(HASHES_FILE, data)

    print("Regenerating package-lock.json...")
    regenerate_lockfile(new_cli)

    print("Calculating npmDepsHash...")
    data["npmDepsHash"] = calculate_dependency_hash(
        ".#goose-cli", "npmDepsHash", HASHES_FILE, data
    )
    save_hashes(HASHES_FILE, data)

    print(f"Updated Goose desktop={new_desktop} cli={new_cli}")


if __name__ == "__main__":
    main()
