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

# Update droid binary hashes
sed -i "/x86_64-linux = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash linux x64)\"|" "$FILE"
sed -i "/aarch64-linux = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash linux arm64)\"|" "$FILE"
sed -i "/aarch64-darwin = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash darwin arm64)\"|" "$FILE"

# Update ripgrep hashes
sed -i "/rgSources = {/,/};/ {
  /x86_64-linux = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_rg_hash linux x64)\"|
}" "$FILE"
sed -i "/rgSources = {/,/};/ {
  /aarch64-linux = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_rg_hash linux arm64)\"|
}" "$FILE"
sed -i "/rgSources = {/,/};/ {
  /aarch64-darwin = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_rg_hash darwin arm64)\"|
}" "$FILE"

echo "Updated droid to $VERSION"
