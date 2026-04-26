#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for context-hub package.

Upstream does not tag releases.  We track the default branch HEAD and
take the version from cli/package.json at that commit, so the derivation
version stays meaningful while the rev pins a reproducible source.
"""

import sys
from pathlib import Path
from typing import cast

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_json,
    load_hashes,
    save_hashes,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

PKG_DIR = Path(__file__).parent
HASHES_FILE = PKG_DIR / "hashes.json"

OWNER = "andrewyng"
REPO = "context-hub"
BRANCH = "main"


def main() -> None:
    """Update the context-hub package."""
    data = load_hashes(HASHES_FILE)
    current_rev = data["rev"]

    head = cast(
        "dict[str, str]",
        fetch_json(f"https://api.github.com/repos/{OWNER}/{REPO}/commits/{BRANCH}"),
    )
    rev = head["sha"]

    print(f"Current rev: {current_rev[:12]}, Latest rev: {rev[:12]}")

    if rev == current_rev:
        print("Already up to date")
        return

    pkg_json = cast(
        "dict[str, str]",
        fetch_json(
            f"https://raw.githubusercontent.com/{OWNER}/{REPO}/{rev}/cli/package.json"
        ),
    )
    version = pkg_json["version"]

    print(
        f"Updating context-hub: {data['version']} ({current_rev[:12]}) -> {version} ({rev[:12]})"
    )

    print("Calculating source hash...")
    url = f"https://github.com/{OWNER}/{REPO}/archive/{rev}.tar.gz"
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": version,
        "rev": rev,
        "hash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    try:
        npm_deps_hash = calculate_dependency_hash(
            ".#context-hub", "npmDepsHash", HASHES_FILE, data
        )
        data["npmDepsHash"] = npm_deps_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated context-hub to {version} ({rev[:12]})")


if __name__ == "__main__":
    main()
