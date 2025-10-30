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
  local section=$1      # "sources" or "rgSources"
  local platform=$2     # "x86_64-linux", "aarch64-linux", or "aarch64-darwin"
  local url_pattern=$3
  local path_platform=$4
  local arch=$5
  local binary_name=$6
  
  # Build URL - ripgrep doesn't use version in path
  local url
  if [[ "$section" == "rgSources" ]]; then
    url="https://downloads.factory.ai/${url_pattern}/${path_platform}/${arch}/${binary_name}"
  else
    url="https://downloads.factory.ai/${url_pattern}/${VERSION}/${path_platform}/${arch}/${binary_name}"
  fi
  
  echo "Fetching hash for ${platform} ${binary_name}..." >&2
  local new_hash
  new_hash=$(nix store prefetch-file --hash-type sha256 "$url" --json | jq -r .hash)
  
  # Extract the old hash from the file using nix eval
  local old_hash
  old_hash=$(nix eval --raw ".#droid.passthru.${section}.${platform}.hash" 2>/dev/null || echo "")
  
  if [ -z "$old_hash" ]; then
    echo "Warning: Could not extract old hash using nix eval, falling back to grep" >&2
    old_hash=$(grep -A1 "${url_pattern}.*${path_platform}.*${arch}.*${binary_name}" "$FILE" | grep hash | grep -oP 'sha256-[^"]+')
  fi
  
  if [ -n "$old_hash" ] && [ "$old_hash" != "$new_hash" ]; then
    echo "Replacing $old_hash with $new_hash for ${platform} ${binary_name}" >&2
    # Use a more targeted sed that finds the URL line and replaces the hash on the next line
    sed -i "/${url_pattern//\//\\/}.*${path_platform}.*${arch}.*${binary_name}/,/hash =/ s|${old_hash}|${new_hash}|" "$FILE"
  elif [ "$old_hash" == "$new_hash" ]; then
    echo "Hash for ${platform} ${binary_name} is already up to date" >&2
  else
    echo "Warning: Could not find old hash for ${platform} ${binary_name}" >&2
  fi
}

echo "Updating droid to version $VERSION..."

# Update version
sed -i "s/version = \".*\"/version = \"$VERSION\"/" "$FILE"

# Update droid binary hashes
fetch_and_update_hash "sources" "x86_64-linux" "factory-cli/releases" "linux" "x64" "droid"
fetch_and_update_hash "sources" "aarch64-linux" "factory-cli/releases" "linux" "arm64" "droid"
fetch_and_update_hash "sources" "aarch64-darwin" "factory-cli/releases" "darwin" "arm64" "droid"

# Update ripgrep hashes
fetch_and_update_hash "rgSources" "x86_64-linux" "ripgrep" "linux" "x64" "rg"
fetch_and_update_hash "rgSources" "aarch64-linux" "ripgrep" "linux" "arm64" "rg"
fetch_and_update_hash "rgSources" "aarch64-darwin" "ripgrep" "darwin" "arm64" "rg"

echo "Updated droid to $VERSION"
