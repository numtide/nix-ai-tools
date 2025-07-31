#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @qwen-code/qwen-code version)
echo "Latest version: $latest_version"

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

# Update URL with new version
sed -i "s|/@qwen-code/qwen-code/-/qwen-code-[0-9a-zA-Z.-]\+\.tgz|/@qwen-code/qwen-code/-/qwen-code-${latest_version}.tgz|" "$package_file"

# Set dummy hash to get the correct one
sed -i 's|hash = "sha256-[^"]*"|hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' "$package_file"

# Build to get the correct hash
echo "Getting tarball hash..."
if output=$(nix build "$script_dir/../.."#qwen-code 2>&1); then
  echo "ERROR: Build succeeded with dummy hash!"
  exit 1
else
  # Extract the correct hash
  if hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got: *//' | xargs); then
    echo "New hash: $hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$hash|" "$package_file"
  else
    echo "ERROR: Could not extract hash from build output"
    echo "Build output:"
    echo "$output" | tail -20
    exit 1
  fi
fi

echo "Update completed successfully!"
echo "qwen-code has been updated from $current_version to $latest_version"
