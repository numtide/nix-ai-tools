#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get latest release from GitHub
latest_version=$(curl -s https://api.github.com/repos/zed-industries/claude-code-acp/releases/latest | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
  echo "ERROR: Could not fetch latest version"
  exit 1
fi

echo "Latest version: $latest_version"

# Extract current version using nix eval (if available)
current_version=$(nix eval .#claude-code-acp.version --raw 2>/dev/null || echo "unknown")
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Update version in package.nix
sed -i "s/version = \".*\";/version = \"$latest_version\";/" package.nix

# Get source hash using nix-prefetch-url
echo "Getting source hash..."
tarball_url="https://github.com/zed-industries/claude-code-acp/archive/v$latest_version.tar.gz"
src_hash_raw=$(nix-prefetch-url --unpack "$tarball_url" 2>/dev/null)

if [ -z "$src_hash_raw" ]; then
  echo "ERROR: Could not fetch source hash"
  exit 1
fi

# Convert to SRI format
src_hash=$(nix hash to-sri --type sha256 "$src_hash_raw")
echo "Source hash: $src_hash"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$src_hash\"|" package.nix

# Set dummy npm deps hash to get the real one
sed -i 's|npmDepsHash = "sha256-[^"]*"|npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' package.nix

# Build to get the correct npm deps hash
echo "Building to get npm deps hash..."
output=$(nix build ../..#claude-code-acp 2>&1 || true)

# Extract the correct npm deps hash
if npm_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got:[[:space:]]*//' | head -1); then
  if [ -n "$npm_hash" ]; then
    echo "NPM deps hash: $npm_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$npm_hash|" package.nix
  else
    echo "ERROR: Could not extract npm deps hash from build output"
    echo "Build output:"
    echo "$output" | tail -50
    exit 1
  fi
fi

echo "Update complete for claude-code-acp $latest_version!"

# Test the build
echo "Testing final build..."
if nix build ../..#claude-code-acp; then
  echo "✓ Build successful!"
  if [ -f result/bin/claude-code-acp ]; then
    version_output=$(result/bin/claude-code-acp --version 2>&1 || true)
    echo "✓ Binary version: $version_output"
  fi
else
  echo "⚠ Build failed - manual intervention may be required"
fi
