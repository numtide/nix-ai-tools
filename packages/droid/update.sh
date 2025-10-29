#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git
# shellcheck shell=bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FILE="$ROOT/packages/droid/package.nix"

echo "Fetching latest droid version from Factory AI..."

# Extract version from the official installation script
VERSION=$(curl -fsSL https://app.factory.ai/cli | grep -oP 'VER="\K[^"]+')

echo "Found version: $VERSION"

fetch_hash() {
  local platform=$1
  local arch=$2
  local url="https://downloads.factory.ai/factory-cli/releases/${VERSION}/${platform}/${arch}/droid"
  echo "Fetching hash for ${platform}/${arch}..." >&2
  nix store prefetch-file --hash-type sha256 "$url" --json | jq -r .hash
}

fetch_rg_hash() {
  local platform=$1
  local arch=$2
  local url="https://downloads.factory.ai/ripgrep/${platform}/${arch}/rg"
  echo "Fetching rg hash for ${platform}/${arch}..." >&2
  nix store prefetch-file --hash-type sha256 "$url" --json | jq -r .hash
}

echo "Updating droid to version $VERSION..."

# Update version
sed -i "s/version = \".*\"/version = \"$VERSION\"/" "$FILE"

# Fetch all hashes first to avoid issues with command substitution in sed
echo "Fetching droid binary hashes..."
HASH_LINUX_X64=$(fetch_hash linux x64)
HASH_LINUX_ARM64=$(fetch_hash linux arm64)
HASH_DARWIN_ARM64=$(fetch_hash darwin arm64)

echo "Fetching ripgrep hashes..."
RG_HASH_LINUX_X64=$(fetch_rg_hash linux x64)
RG_HASH_LINUX_ARM64=$(fetch_rg_hash linux arm64)
RG_HASH_DARWIN_ARM64=$(fetch_rg_hash darwin arm64)

# Update droid binary hashes in sources section
# Use more specific patterns that include the URL pattern to target only sources section
sed -i "/factory-cli\/releases.*x64\/droid/,/hash =/ s|hash = \"sha256-[^\"]*\"|hash = \"${HASH_LINUX_X64}\"|" "$FILE"
sed -i "/factory-cli\/releases.*arm64\/droid/,/hash =/ s|hash = \"sha256-[^\"]*\"|hash = \"${HASH_LINUX_ARM64}\"|" "$FILE"  
sed -i "/factory-cli\/releases.*darwin.*arm64\/droid/,/hash =/ s|hash = \"sha256-[^\"]*\"|hash = \"${HASH_DARWIN_ARM64}\"|" "$FILE"

# Update ripgrep hashes in rgSources section  
# Use URL patterns specific to ripgrep
sed -i "/ripgrep.*linux\/x64\/rg/,/hash =/ s|hash = \"sha256-[^\"]*\"|hash = \"${RG_HASH_LINUX_X64}\"|" "$FILE"
sed -i "/ripgrep.*linux\/arm64\/rg/,/hash =/ s|hash = \"sha256-[^\"]*\"|hash = \"${RG_HASH_LINUX_ARM64}\"|" "$FILE"
sed -i "/ripgrep.*darwin\/arm64\/rg/,/hash =/ s|hash = \"sha256-[^\"]*\"|hash = \"${RG_HASH_DARWIN_ARM64}\"|" "$FILE"

echo "Updated droid to $VERSION"
