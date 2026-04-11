#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex package.

This script updates both the codex version and the librusty_v8 hashes.
The v8 version is extracted from the Cargo.lock file of the codex repository.
"""

import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_platform_hashes,
    calculate_url_hash,
    fetch_github_latest_release,
    fetch_version_from_text,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError

HASHES_FILE = Path(__file__).parent / "hashes.json"

RUSTY_V8_PLATFORMS = {
    "x86_64-linux": "x86_64-unknown-linux-gnu",
    "aarch64-linux": "aarch64-unknown-linux-gnu",
    "x86_64-darwin": "x86_64-apple-darwin",
    "aarch64-darwin": "aarch64-apple-darwin",
}

# codex-realtime-webrtc only enables livekit/webrtc-sys on macOS, so we
# only need to prefetch the darwin prebuilt archives.
LIVEKIT_WEBRTC_PLATFORMS = {
    "x86_64-darwin": "mac-x64",
    "aarch64-darwin": "mac-arm64",
}


def fetch_version() -> str:
    """Fetch latest codex version from GitHub releases."""
    tag = fetch_github_latest_release("openai", "codex")
    match = re.match(r"^rust-v(.+)$", tag)
    if not match:
        msg = f"Unexpected tag format: {tag!r}, expected 'rust-v<version>'"
        raise ValueError(msg)
    return match.group(1)


def librusty_v8_pins(
    codex_version: str, previous: dict[str, Any] | None
) -> dict[str, Any]:
    """Return the librusty_v8 pin for the given codex version.

    Re-uses existing hashes when the v8 version has not changed to avoid
    re-downloading four ~100MB archives on every bump.
    """
    v8_version = fetch_version_from_text(
        f"https://raw.githubusercontent.com/openai/codex/rust-v{codex_version}/codex-rs/Cargo.lock",
        r'name = "v8"\nversion = "([^"]+)"',
    )
    print(f"V8 version: {v8_version}")

    if previous and previous.get("version") == v8_version:
        print("V8 unchanged, reusing hashes")
        return previous

    hashes = calculate_platform_hashes(
        "https://github.com/denoland/rusty_v8/releases/download/"
        "v{version}/librusty_v8_release_{platform}.a.gz",
        RUSTY_V8_PLATFORMS,
        version=v8_version,
    )
    return {"version": v8_version, "hashes": {k: hashes[k] for k in RUSTY_V8_PLATFORMS}}


def livekit_webrtc_pins(
    codex_version: str, previous: dict[str, Any] | None
) -> dict[str, Any]:
    """Return the prebuilt livekit webrtc pin for the given codex version.

    codex pins a fork of livekit/rust-sdks via a git revision; that crate's
    ``webrtc-sys-build`` hard-codes the upstream release tag to download.
    Re-uses existing hashes when the tag is unchanged to avoid re-downloading
    two ~300MB archives on every bump.
    """
    rust_sdks_rev = fetch_version_from_text(
        f"https://raw.githubusercontent.com/openai/codex/rust-v{codex_version}/codex-rs/Cargo.lock",
        r'name = "webrtc-sys-build"\nversion = "[^"]+"\n'
        r'source = "git\+https://github\.com/[^?]+\?rev=([0-9a-f]+)',
    )
    webrtc_tag = fetch_version_from_text(
        f"https://raw.githubusercontent.com/juberti-oai/rust-sdks/{rust_sdks_rev}/webrtc-sys/build/src/lib.rs",
        r'WEBRTC_TAG: &str = "([^"]+)"',
    )
    print(f"livekit webrtc tag: {webrtc_tag} (rust-sdks rev {rust_sdks_rev[:10]})")

    if previous and previous.get("tag") == webrtc_tag:
        print("livekit webrtc unchanged, reusing hashes")
        return previous

    hashes = {
        nix_platform: calculate_url_hash(
            "https://github.com/livekit/rust-sdks/releases/download/"
            f"{webrtc_tag}/webrtc-{triple}-release.zip",
            unpack=True,
        )
        for nix_platform, triple in LIVEKIT_WEBRTC_PLATFORMS.items()
    }
    return {"tag": webrtc_tag, "hashes": hashes}


def main() -> None:
    """Update the codex package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tag = f"rust-v{latest}"
    url = f"https://github.com/openai/codex/archive/refs/tags/{tag}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "librusty_v8": librusty_v8_pins(latest, data.get("librusty_v8")),
        "livekit_webrtc": livekit_webrtc_pins(latest, data.get("livekit_webrtc")),
    }
    save_hashes(HASHES_FILE, data)

    try:
        cargo_hash = calculate_dependency_hash(
            ".#codex", "cargoHash", HASHES_FILE, data
        )
        data["cargoHash"] = cargo_hash
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
