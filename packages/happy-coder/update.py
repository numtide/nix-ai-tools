#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for happy-coder.

Upstream is the slopus/happy yarn-workspaces monorepo, which does not tag
the CLI. We track the ``happy`` npm tarball (prebuilt dist/, no lockfile)
and pair it with the monorepo's root yarn.lock at the commit that bumped
``packages/happy-cli/package.json`` to that version.

``@slopus/happy-wire`` is a workspace sibling (no lockfile entry) but a
regular npm dependency in the published tarball; we pin its registry
metadata too so the build can append a synthetic lock stanza.
"""

import json
import sys
import urllib.request
from pathlib import Path
from typing import Any, cast

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_json,
    fetch_npm_version,
    load_hashes,
    nix_build,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from updater.nix import NixCommandError, nix_store_prefetch_file

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
NPM_PACKAGE = "happy"
WIRE_PACKAGE = "@slopus/happy-wire"
MONOREPO = "slopus/happy"
CLI_PACKAGE_JSON = "packages/happy-cli/package.json"


def find_release_commit(version: str) -> str:
    """Find the monorepo commit that bumped happy-cli to ``version``.

    Walks the commit history of packages/happy-cli/package.json until the
    blob at that commit reports the matching version. The yarn.lock at that
    SHA is what produced the published tarball.
    """
    commits_url = (
        f"https://api.github.com/repos/{MONOREPO}/commits"
        f"?path={CLI_PACKAGE_JSON}&per_page=30"
    )
    commits = cast("list[dict[str, Any]]", fetch_json(commits_url))

    for commit in commits:
        sha = commit["sha"]
        raw_url = (
            f"https://raw.githubusercontent.com/{MONOREPO}/{sha}/{CLI_PACKAGE_JSON}"
        )
        with urllib.request.urlopen(raw_url, timeout=30) as resp:
            pkg = json.loads(resp.read())
        if pkg.get("version") == version:
            return cast("str", sha)

    msg = (
        f"No commit on {MONOREPO}:{CLI_PACKAGE_JSON} declares version {version}. "
        "The release may have been published from a branch not yet merged."
    )
    raise RuntimeError(msg)


def fetch_wire_pin(range_spec: str) -> dict[str, str]:
    """Resolve the workspace-only dep against the npm registry.

    The yarn.lock has no entry for happy-wire (it's a workspace package
    upstream), so we synthesize one. Uses npm's max-satisfying resolution
    against the range from the tarball's package.json.
    """
    meta = cast(
        "dict[str, Any]",
        fetch_json(f"https://registry.npmjs.org/{WIRE_PACKAGE}"),
    )
    # dist-tags.latest is what `^x.y.z` resolves to in practice for this
    # package; if upstream ever publishes prereleases this may need a
    # proper semver matcher.
    resolved_version = meta["dist-tags"]["latest"]
    dist = meta["versions"][resolved_version]["dist"]
    return {
        "wireRange": range_spec,
        "wireVersion": resolved_version,
        "wireResolved": f"{dist['tarball']}#{dist['shasum']}",
        "wireIntegrity": dist["integrity"],
    }


def fetch_wire_range(version: str) -> str:
    """Read the @slopus/happy-wire dependency range from the npm tarball."""
    pkg = cast(
        "dict[str, Any]",
        fetch_json(f"https://registry.npmjs.org/{NPM_PACKAGE}/{version}"),
    )
    return cast("str", pkg["dependencies"][WIRE_PACKAGE])


def calculate_yarn_offline_hash(data: dict[str, Any]) -> str:
    """Get the fetchYarnDeps FOD hash via dummy-hash-and-build.

    Mirrors ``calculate_dependency_hash`` but inlined: we want to leave
    hashes.json with the dummy in place if extraction fails so the user
    can inspect the build error.
    """
    print("Calculating yarnOfflineHash...")
    data["yarnOfflineHash"] = DUMMY_SHA256_HASH
    save_hashes(HASHES_FILE, data)

    try:
        nix_build(".#happy-coder", check=True)
    except NixCommandError as e:
        got = extract_hash_from_build_error(e.args[0])
        if got is None:
            msg = f"Could not extract hash from build error:\n{e.args[0]}"
            raise ValueError(msg) from e
        return got

    msg = "Build succeeded with dummy hash — fetchYarnDeps did not run?"
    raise ValueError(msg)


def main() -> None:
    """Update the happy-coder package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")
    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball = f"https://registry.npmjs.org/{NPM_PACKAGE}/-/{NPM_PACKAGE}-{latest}.tgz"
    print("Calculating source hash...")
    src_hash = calculate_url_hash(tarball, unpack=True)

    print("Locating monorepo commit for this release...")
    lock_commit = find_release_commit(latest)
    lock_url = f"https://raw.githubusercontent.com/{MONOREPO}/{lock_commit}/yarn.lock"
    print(f"  -> {lock_commit[:12]}")
    lock_hash = nix_store_prefetch_file(lock_url)

    print("Resolving @slopus/happy-wire...")
    wire_range = fetch_wire_range(latest)
    wire_pin = fetch_wire_pin(wire_range)

    new_data: dict[str, Any] = {
        "version": latest,
        "srcHash": src_hash,
        "yarnLockCommit": lock_commit,
        "yarnLockHash": lock_hash,
        "yarnOfflineHash": data["yarnOfflineHash"],
        **wire_pin,
    }

    new_data["yarnOfflineHash"] = calculate_yarn_offline_hash(new_data)
    save_hashes(HASHES_FILE, new_data)
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
