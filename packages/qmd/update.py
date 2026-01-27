#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for qmd package."""

import sys
from pathlib import Path
from typing import cast

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_json,
    load_hashes,
    save_hashes,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"
OWNER = "tobi"
REPO = "qmd"


def fetch_latest_commit() -> tuple[str, str]:
    """Fetch the latest commit SHA and date from the default branch.

    Returns:
        Tuple of (commit SHA, commit date in YYYY-MM-DD format)

    """
    url = f"https://api.github.com/repos/{OWNER}/{REPO}/commits/main"
    data = fetch_json(url)
    if not isinstance(data, dict):
        msg = f"Expected dict from GitHub API, got {type(data)}"
        raise TypeError(msg)

    sha = cast("str", data["sha"])
    # commit.committer.date is in ISO 8601 format
    commit_date = cast("str", data["commit"]["committer"]["date"])[:10]
    return sha, commit_date


def main() -> None:
    """Update the qmd package."""
    data = load_hashes(HASHES_FILE)
    current_rev = data["rev"]

    latest_rev, commit_date = fetch_latest_commit()
    print(f"Current rev: {current_rev[:8]}")
    print(f"Latest rev:  {latest_rev[:8]} ({commit_date})")

    if current_rev == latest_rev:
        print("Already up to date")
        return

    print(f"Updating qmd to {latest_rev[:8]}...")

    # Calculate new source hash
    tarball_url = f"https://github.com/{OWNER}/{REPO}/archive/{latest_rev}.tar.gz"
    print(f"Calculating source hash for {tarball_url}...")
    src_hash = calculate_url_hash(tarball_url, unpack=True)
    print(f"  srcHash: {src_hash}")

    # Update hashes.json (keep npmDepsHash unchanged)
    new_data = {
        "rev": latest_rev,
        "srcHash": src_hash,
        "npmDepsHash": data["npmDepsHash"],
    }

    save_hashes(HASHES_FILE, new_data)
    print(f"Updated to {latest_rev[:8]} ({commit_date})")
    print(
        "Note: npmDepsHash unchanged. If build fails, update manually from error output."
    )


if __name__ == "__main__":
    main()
