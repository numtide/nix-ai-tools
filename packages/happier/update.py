#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for happier.

Track the published ``@happier-dev/cli`` npm tarball and pair it with the
monorepo root yarn.lock from the matching ``cli-v<version>`` tag.
"""

import sys
from pathlib import Path
from typing import Any, cast

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_json,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import nix_store_prefetch_file

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
NPM_PACKAGE = "@happier-dev/cli"
MONOREPO = "happier-dev/happier"


def find_release_commit(version: str) -> str:
    """Resolve the commit behind the ``cli-v<version>`` tag."""
    tag = f"cli-v{version}"
    ref = cast(
        "dict[str, Any]",
        fetch_json(f"https://api.github.com/repos/{MONOREPO}/git/ref/tags/{tag}"),
    )
    target = cast("dict[str, Any]", ref["object"])

    if target["type"] == "commit":
        return cast("str", target["sha"])

    if target["type"] == "tag":
        annotated = cast(
            "dict[str, Any]",
            fetch_json(
                f"https://api.github.com/repos/{MONOREPO}/git/tags/{target['sha']}",
            ),
        )
        annotated_target = cast("dict[str, Any]", annotated["object"])
        if annotated_target["type"] == "commit":
            return cast("str", annotated_target["sha"])

    msg = f"Tag {tag} did not resolve to a commit"
    raise RuntimeError(msg)


def main() -> None:
    """Update the happier package pins."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)
    refresh_dependency_hash = data["yarnOfflineHash"] == DUMMY_SHA256_HASH

    print(f"Current: {current}, Latest: {latest}")
    if not should_update(current, latest) and not refresh_dependency_hash:
        print("Already up to date")
        return

    if refresh_dependency_hash:
        print("Refreshing dummy yarnOfflineHash...")

    tarball = f"https://registry.npmjs.org/@happier-dev/cli/-/cli-{latest}.tgz"
    print("Calculating source hash...")
    src_hash = calculate_url_hash(tarball, unpack=True)

    print("Locating monorepo commit for this release...")
    lock_commit = find_release_commit(latest)
    lock_url = f"https://raw.githubusercontent.com/{MONOREPO}/{lock_commit}/yarn.lock"
    lock_hash = nix_store_prefetch_file(lock_url)

    new_data: dict[str, Any] = {
        "version": latest,
        "srcHash": src_hash,
        "yarnLockCommit": lock_commit,
        "yarnLockHash": lock_hash,
        "yarnOfflineHash": data["yarnOfflineHash"],
    }

    new_data["yarnOfflineHash"] = calculate_dependency_hash(
        ".#happier",
        "yarnOfflineHash",
        HASHES_FILE,
        new_data,
    )

    save_hashes(HASHES_FILE, new_data)
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
