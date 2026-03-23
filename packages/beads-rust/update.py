#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for beads-rust package.

Upstream uses [patch.crates-io] with local path deps to sibling
frankensqlite and asupersync repos.  This script updates beads_rust
and the matching sibling commits in hashes.json, then recalculates
cargoHash via a dummy-hash build.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_url_hash,
    fetch_github_latest_release,
    fetch_json,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"
OWNER = "Dicklesworthstone"
BEADS_REPO = "beads_rust"
FRANK_REPO = "frankensqlite"
ASYNC_REPO = "asupersync"


def get_release_date(owner: str, repo: str, version: str) -> str:
    """Get the creation date of a GitHub release."""
    url = f"https://api.github.com/repos/{owner}/{repo}/releases/tags/v{version}"
    data = fetch_json(url)
    if not isinstance(data, dict):
        msg = f"Unexpected API response for {url}"
        raise TypeError(msg)
    return str(data["created_at"])


def get_sibling_rev(repo: str, until: str) -> str:
    """Get the latest commit of a sibling repo at or before a given date."""
    url = (
        f"https://api.github.com/repos/{OWNER}/{repo}/commits?until={until}&per_page=1"
    )
    data = fetch_json(url)
    if not isinstance(data, list) or len(data) == 0:
        msg = f"No {repo} commits found"
        raise ValueError(msg)
    return str(data[0]["sha"])


def prefetch_github(owner: str, repo: str, rev: str) -> str:
    """Prefetch a GitHub archive and return its SRI hash."""
    url = f"https://github.com/{owner}/{repo}/archive/{rev}.tar.gz"
    return calculate_url_hash(url, unpack=True)


def main() -> None:
    """Update beads-rust and its frankensqlite dependency."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release(OWNER, BEADS_REPO)

    print(f"beads-rust: current={current}, latest={latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    # Update beads_rust src hash
    print(f"Prefetching beads_rust v{latest}...")
    src_hash = prefetch_github(OWNER, BEADS_REPO, f"v{latest}")
    data["version"] = latest
    data["hash"] = src_hash

    # Update sibling repos to commits matching the release date
    release_date = get_release_date(OWNER, BEADS_REPO, latest)

    for name, repo in [("frankensqlite", FRANK_REPO), ("asupersync", ASYNC_REPO)]:
        print(f"Finding {name} commit matching v{latest} release...")
        rev = get_sibling_rev(repo, release_date)
        print(f"{name} rev: {rev}")

        print(f"Prefetching {name}...")
        h = prefetch_github(OWNER, repo, rev)
        data[name] = {"rev": rev, "hash": h}

    # Recalculate cargoHash via dummy-hash build
    cargo_hash = calculate_dependency_hash(
        ".#beads-rust", "cargoHash", HASHES_FILE, data
    )
    data["cargoHash"] = cargo_hash

    save_hashes(HASHES_FILE, data)
    print(f"Updated beads-rust to {latest}")


if __name__ == "__main__":
    main()
