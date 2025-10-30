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
  local url_pattern=$1
  local platform=$2
  local arch=$3
  local binary_name=$4
  
  # Build URL - ripgrep doesn't use version in path
  local url
  if [[ "$url_pattern" == "ripgrep" ]]; then
    url="https://downloads.factory.ai/${url_pattern}/${platform}/${arch}/${binary_name}"
  else
    url="https://downloads.factory.ai/${url_pattern}/${VERSION}/${platform}/${arch}/${binary_name}"
  fi
  
  echo "Fetching hash for ${platform}/${arch} ${binary_name}..." >&2
  local new_hash
  new_hash=$(nix store prefetch-file --hash-type sha256 "$url" --json | jq -r .hash)
  
  # Extract the old hash from the file for this specific URL line
  local old_hash
  old_hash=$(grep -A1 "${url_pattern}.*${platform}.*${arch}.*${binary_name}" "$FILE" | grep hash | grep -oP 'sha256-[^"]+')
  
  if [ -n "$old_hash" ] && [ "$old_hash" != "$new_hash" ]; then
    echo "Replacing $old_hash with $new_hash for ${platform}/${arch} ${binary_name}" >&2
    # Use a more targeted sed that finds the URL line and replaces the hash on the next line
    sed -i "/${url_pattern//\//\\/}.*${platform}.*${arch}.*${binary_name}/,/hash =/ s|${old_hash}|${new_hash}|" "$FILE"
  elif [ "$old_hash" == "$new_hash" ]; then
    echo "Hash for ${platform}/${arch} ${binary_name} is already up to date" >&2
  else
    echo "Warning: Could not find old hash for ${platform}/${arch} ${binary_name}" >&2
  fi
}

echo "Updating droid to version $VERSION..."

# Update version
sed -i "s/version = \".*\"/version = \"$VERSION\"/" "$FILE"

# Update droid binary hashes
fetch_and_update_hash "factory-cli/releases" "linux" "x64" "droid"
fetch_and_update_hash "factory-cli/releases" "linux" "arm64" "droid"
fetch_and_update_hash "factory-cli/releases" "darwin" "arm64" "droid"

# Update ripgrep hashes
fetch_and_update_hash "ripgrep" "linux" "x64" "rg"
fetch_and_update_hash "ripgrep" "linux" "arm64" "rg"
fetch_and_update_hash "ripgrep" "darwin" "arm64" "rg"

echo "Updated droid to $VERSION"
