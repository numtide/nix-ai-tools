#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest stable version from GitHub (exclude nightly/pre-release versions)
echo "Fetching latest stable version from GitHub..."
# Get all releases and filter out nightly/pre-release versions
latest_version=$(curl -s https://api.github.com/repos/QwenLM/qwen-code/releases | \
  jq -r '.[] | select(.prerelease == false) | .tag_name' | \
  head -1 | \
  sed 's/^v//')

if [ -z "$latest_version" ]; then
  echo "ERROR: Could not find a stable release"
  exit 1
fi
echo "Latest stable version: $latest_version"

# Extract current version from package.nix
current_version=$(grep -oP 'version = "\K[^"]+' "$package_file" | head -1)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Step 1: Update the source hash
echo "Getting source hash..."
# Set dummy hash for src (first hash in file)
sed -i '0,/hash = "sha256-[^"]*"/{s|hash = "sha256-[^"]*"|hash = "sha256-0000000000000000000000000000000000000000000="|;}' "$package_file"

# Build to get the correct source hash
if output=$(nix build "$script_dir/../.."#qwen-code 2>&1); then
  echo "ERROR: Build succeeded with dummy hash!"
  exit 1
else
  # Extract the correct hash for src
  if src_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got: *//' | xargs); then
    echo "New source hash: $src_hash"
    sed -i "s|sha256-0000000000000000000000000000000000000000000=|$src_hash|" "$package_file"
  else
    echo "ERROR: Could not extract source hash from build output"
    echo "Build output:"
    echo "$output" | tail -20
    exit 1
  fi
fi

# Step 2: Update the npmDeps hash
echo "Getting npm dependencies hash..."
# Set dummy hash for npmDeps (second hash in file) - using different pattern
awk '/npmDeps = fetchNpmDeps/,/};/ {if (/hash =/) {sub(/hash = "sha256-[^"]*"/, "hash = \"sha256-1111111111111111111111111111111111111111111=\"")}} 1' "$package_file" > "$package_file.tmp" && mv "$package_file.tmp" "$package_file"

# Build again to get the npmDeps hash
if output=$(nix build "$script_dir/../.."#qwen-code 2>&1); then
  echo "Build succeeded!"
else
  # Extract the correct hash for npmDeps
  if npm_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got: *//' | xargs); then
    echo "New npm dependencies hash: $npm_hash"
    sed -i "s|sha256-1111111111111111111111111111111111111111111=|$npm_hash|" "$package_file"
  else
    echo "ERROR: Could not extract npm dependencies hash from build output"
    echo "Build output:"
    echo "$output" | tail -20
    exit 1
  fi
fi

echo "Update completed successfully!"
echo "qwen-code has been updated from $current_version to $latest_version"
