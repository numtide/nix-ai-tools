#!/usr/bin/env python3
"""Merge platform-specific hash updates into a single hashes.json file."""

import json
import sys
from pathlib import Path


def main() -> None:
    """Merge hash files and validate all platforms have hashes."""
    base_file = Path("packages/opencode/hashes.json")
    hash_dir = Path("/tmp/hashes")

    # Load base hashes
    with base_file.open() as f:
        merged = json.load(f)

    # Merge all platform-specific hash updates
    for hash_file in sorted(hash_dir.glob("hash-*/hashes.json")):
        print(f"Merging hashes from {hash_file}")
        with hash_file.open() as f:
            platform_hashes = json.load(f)

        # Merge node_modules hashes, with platform-specific updates taking precedence
        if "node_modules" in platform_hashes:
            merged.setdefault("node_modules", {}).update(
                platform_hashes["node_modules"]
            )

    # Validate all platforms have hashes
    required_platforms = [
        "x86_64-linux",
        "aarch64-linux",
        "x86_64-darwin",
        "aarch64-darwin",
    ]
    for platform in required_platforms:
        hash_value = merged.get("node_modules", {}).get(platform)
        if not hash_value:
            print(f"ERROR: Missing hash for platform {platform}")
            sys.exit(1)
        print(f"✓ {platform}: {hash_value}")

    # Write merged hashes back
    with base_file.open("w") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
