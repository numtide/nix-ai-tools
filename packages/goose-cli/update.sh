#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get latest version from GitHub API
latest_version=$(curl -sL https://api.github.com/repos/block/goose/releases/latest | jq -r '.tag_name' | sed 's/^v//')

echo "Latest version: $latest_version"

# Update version in package.nix
sed -i "s/version = \".*\"/version = \"$latest_version\"/" package.nix

# Update hashes for each platform
platforms=(
  "x86_64-linux:x86_64-unknown-linux-gnu"
  "aarch64-linux:aarch64-unknown-linux-gnu"
  "x86_64-darwin:x86_64-apple-darwin"
  "aarch64-darwin:aarch64-apple-darwin"
)

for platform_spec in "${platforms[@]}"; do
  nix_platform="${platform_spec%%:*}"
  goose_platform="${platform_spec##*:}"

  url="https://github.com/block/goose/releases/download/v$latest_version/goose-$goose_platform.tar.bz2"

  echo "Fetching hash for $nix_platform..."
  hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | xargs -I {} nix hash convert --hash-algo sha256 {} 2>/dev/null || echo "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")

  # Update the hash in package.nix
  sed -i "/$nix_platform = {/,/};/ s|hash = \".*\"|hash = \"$hash\"|" package.nix
done

echo "Update complete!"
