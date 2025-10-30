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

fetch_and_update_hash() {
  local section=$1  # "sources" or "rgSources"
  local platform=$2 # "x86_64-linux", "aarch64-linux", or "aarch64-darwin"
  local path_platform=$3
  local arch=$4
  local binary_name=$5

  # Build URL - ripgrep doesn't use version in path
  local url
  if [[ $section == "rgSources" ]]; then
    url="https://downloads.factory.ai/ripgrep/${path_platform}/${arch}/${binary_name}"
  else
    url="https://downloads.factory.ai/factory-cli/releases/${VERSION}/${path_platform}/${arch}/${binary_name}"
  fi

  echo "Fetching hash for ${platform} ${binary_name}..." >&2
  local new_hash
  new_hash=$(nix store prefetch-file --hash-type sha256 "$url" --json | jq -r .hash)

  if [ -z "$new_hash" ]; then
    echo "Error: Failed to fetch new hash for ${section}.${platform}" >&2
    return 1
  fi

  # Get the old hash using nix eval
  local old_hash
  old_hash=$(nix eval --raw "$ROOT#droid.passthru.${section}.${platform}.hash")

  if [ -z "$old_hash" ]; then
    echo "Error: Failed to get old hash for ${section}.${platform}" >&2
    return 1
  fi

  echo "Replacing $old_hash with $new_hash for ${section}.${platform}" >&2
  # Replace the specific old hash with the new hash
  sed -i "s|${old_hash}|${new_hash}|" "$FILE"
}

echo "Updating droid to version $VERSION..."

# Update version
sed -i "s/version = \".*\"/version = \"$VERSION\"/" "$FILE"

# Update droid binary hashes
fetch_and_update_hash "sources" "x86_64-linux" "linux" "x64" "droid"
fetch_and_update_hash "sources" "aarch64-linux" "linux" "arm64" "droid"
fetch_and_update_hash "sources" "aarch64-darwin" "darwin" "arm64" "droid"

# Update ripgrep hashes
fetch_and_update_hash "rgSources" "x86_64-linux" "linux" "x64" "rg"
fetch_and_update_hash "rgSources" "aarch64-linux" "linux" "arm64" "rg"
fetch_and_update_hash "rgSources" "aarch64-darwin" "darwin" "arm64" "rg"

echo "Updated droid to $VERSION"
