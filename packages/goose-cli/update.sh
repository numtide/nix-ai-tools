#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get latest version from GitHub API
latest_version=$(curl -sL https://api.github.com/repos/block/goose/releases/latest | jq -r '.tag_name' | sed 's/^v//')

echo "Latest version: $latest_version"

# Update version in package.nix
sed -i "s/version = \".*\"/version = \"$latest_version\"/" package.nix

# Get source hash
echo "Getting source hash..."
src_hash=$(nix run nixpkgs#nix-prefetch-github -- block goose --rev "v$latest_version" 2>/dev/null | jq -r .hash)
echo "Source hash: $src_hash"

# Update source hash
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$src_hash\"|g" package.nix

# Set dummy cargo hash to get the real one
sed -i 's|cargoHash = "sha256-[^"]*"|cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' package.nix

# Build to get the correct cargo hash
echo "Building to get cargo vendor hash..."
if output=$(nix build ../..#goose-cli 2>&1); then
  echo "Build succeeded with dummy hash - something is wrong!"
  exit 1
else
  # Extract the correct cargo hash
  if cargo_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got:[[:space:]]*//' | head -1); then
    echo "Cargo vendor hash: $cargo_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$cargo_hash|" package.nix
  else
    echo "ERROR: Could not extract cargo hash from build output"
    echo "Build output:"
    echo "$output" | tail -50
    exit 1
  fi
fi

echo "Update complete!"
