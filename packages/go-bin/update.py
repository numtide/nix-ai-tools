#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for go-bin package.

Fetches the latest patch release of the Go minor version we track from the
official Go download API and updates hashes.json.
"""

import sys
from pathlib import Path
from typing import Any, cast

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    fetch_json,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import hex_to_sri

HASHES_FILE = Path(__file__).parent / "hashes.json"

# Platforms we package, as <os>-<arch> matching Go download filenames.
PLATFORMS = ("linux-amd64", "linux-arm64", "darwin-amd64", "darwin-arm64")


def minor_version(v: str) -> str:
    """Return the major.minor portion of a version string."""
    parts = v.split(".")
    return f"{parts[0]}.{parts[1]}"


def fetch_latest_go_release(minor: str) -> dict[str, Any] | None:
    """Find the latest stable release for a Go minor version.

    The Go download API returns releases newest-first, so the first
    match for our minor wins.
    """
    data = fetch_json("https://go.dev/dl/?mode=json")
    if not isinstance(data, list):
        msg = f"Expected list from Go API, got {type(data)}"
        raise TypeError(msg)
    for release in data:
        ver = cast("str", release["version"]).removeprefix("go")
        if minor_version(ver) == minor and release.get("stable", False):
            return cast("dict[str, Any]", release)
    return None


def extract_platform_hashes(release: dict[str, Any]) -> dict[str, str]:
    """Extract SRI sha256 hashes for each platform from a Go release."""
    hashes: dict[str, str] = {}
    for f in release["files"]:
        if f["kind"] != "archive":
            continue
        key = f"{f['os']}-{f['arch']}"
        if key in PLATFORMS:
            hashes[key] = hex_to_sri(f["sha256"])
    missing = set(PLATFORMS) - set(hashes)
    if missing:
        msg = f"Missing hashes for platforms: {missing}"
        raise ValueError(msg)
    return hashes


def main() -> None:
    """Update the go-bin package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    minor = minor_version(current)

    print(f"Current: {current}, tracking Go {minor}.x")

    release = fetch_latest_go_release(minor)
    if release is None:
        print(f"No stable release found for Go {minor}")
        return

    latest = cast("str", release["version"]).removeprefix("go")
    print(f"Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print("Extracting platform hashes...")
    hashes = extract_platform_hashes(release)
    for plat, h in sorted(hashes.items()):
        print(f"  {plat}: {h}")

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
