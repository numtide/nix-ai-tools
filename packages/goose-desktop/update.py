#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for goose-desktop package."""

import json
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"


def patch_desktop_package_json(desktop_dir: Path) -> None:
    """Rewrite workspace dependencies into Nix-compatible local file deps."""
    package_json_path = desktop_dir / "package.json"
    package_json = json.loads(package_json_path.read_text())

    dependencies = package_json.get("dependencies", {})
    if dependencies.get("@aaif/goose-acp") == "workspace:*":
        dependencies["@aaif/goose-acp"] = "file:../acp"
        package_json["dependencies"] = dependencies
        package_json_path.write_text(json.dumps(package_json, indent=2) + "\n")


def disable_ui_workspace_root(ui_dir: Path) -> None:
    """Prevent npm from trying to resolve unrelated UI workspaces."""
    for name in ("package.json", "pnpm-workspace.yaml"):
        path = ui_dir / name
        if path.exists():
            path.rename(ui_dir / f"{name}.bak")


def generate_desktop_lockfile(version: str) -> None:
    """Generate ui/desktop/package-lock.json for a Goose release."""
    url = f"https://github.com/block/goose/archive/refs/tags/v{version}.tar.gz"

    with tempfile.TemporaryDirectory() as tmpdir:
        tarball_path = Path(tmpdir) / "source.tar.gz"
        urllib.request.urlretrieve(url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir, filter="data")

        repo_root = next(Path(tmpdir).glob("goose-*"))
        ui_dir = repo_root / "ui"
        desktop_dir = repo_root / "ui" / "desktop"
        patch_desktop_package_json(desktop_dir)
        disable_ui_workspace_root(ui_dir)

        subprocess.run(
            [
                "npm",
                "install",
                "--package-lock-only",
                "--ignore-scripts",
                "--legacy-peer-deps",
            ],
            cwd=desktop_dir,
            check=True,
        )

        lockfile_path = desktop_dir / "package-lock.json"
        if not lockfile_path.exists():
            msg = "Failed to generate ui/desktop/package-lock.json"
            raise ValueError(msg)

        (SCRIPT_DIR / "package-lock.json").write_text(lockfile_path.read_text())


def main() -> None:
    """Update the goose-desktop package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release("block", "goose")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    source_url = f"https://github.com/block/goose/archive/refs/tags/v{latest}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(source_url, unpack=True)

    print("Updating package-lock.json...")
    generate_desktop_lockfile(latest)

    data = {
        "version": latest,
        "sourceHash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#goose-desktop", "npmDepsHash", HASHES_FILE, data
        )
        data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
