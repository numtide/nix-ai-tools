#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get latest version from GitHub API releases
latest_version=$(gh api repos/zed-industries/codex-acp/releases/latest --jq '.tag_name' | sed 's/^v//')

if [ -z "$latest_version" ]; then
  echo "ERROR: Could not fetch latest version"
  exit 1
fi

echo "Latest version: $latest_version"

# Update version in package.nix
sed -i "s/version = \".*\"/version = \"$latest_version\"/" package.nix

# Update URLs with new version
sed -i "s|/v[0-9.]*\/codex-acp-|/v$latest_version/codex-acp-|g" package.nix

# Function to get hash for a specific platform binary
get_binary_hash() {
  local platform=$1
  local url="https://github.com/zed-industries/codex-acp/releases/download/v$latest_version/codex-acp-$latest_version-$platform.tar.gz"

  echo "Getting hash for $platform..."
  local hash
  hash=$(nix-prefetch-url "$url" 2>/dev/null)

  if [ -z "$hash" ]; then
    echo "WARNING: Could not fetch hash for $platform"
    return 1
  fi

  # Convert to SRI format
  local sri_hash
  sri_hash=$(nix hash to-sri --type sha256 "$hash")
  echo "  $platform: $sri_hash"

  # Update the hash in package.nix
  sed -i "/$platform\.tar\.gz\";/,/hash = / s|hash = \"sha256-[^\"]*\"|hash = \"$sri_hash\"|" package.nix
}

# Update hashes for all platforms
echo "Updating binary hashes..."
get_binary_hash "x86_64-unknown-linux-gnu"
get_binary_hash "aarch64-unknown-linux-gnu"
get_binary_hash "x86_64-apple-darwin"
get_binary_hash "aarch64-apple-darwin"

echo "Update complete for codex-acp $latest_version!"

# Test the build for current platform
echo "Testing build..."
if nix build ../..#codex-acp; then
  echo "✓ Build successful!"
  if [ -f result/bin/codex-acp ]; then
    version_output=$(result/bin/codex-acp --version 2>&1 || true)
    echo "✓ Binary version: $version_output"
  fi
else
  echo "⚠ Build failed - manual intervention may be required"
fi
