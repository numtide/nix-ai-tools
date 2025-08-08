#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @sourcegraph/amp version)
echo "Latest version: $latest_version"

# Extract current version from package.nix
current_version=$(grep -Po 'version = "\K[^"]+' "$package_file")
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Update URL
sed -i "s|/@sourcegraph/amp/-/amp-[^/]\\+\\.tgz|/@sourcegraph/amp/-/amp-${latest_version}.tgz|" "$package_file"

# Get new hash
echo "Getting new source hash..."
new_hash=$(nix-prefetch-url "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${latest_version}.tgz" | tail -1)
new_sri_hash=$(nix hash to-sri --type sha256 "$new_hash")

# Update hash
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$new_sri_hash\"|" "$package_file"

echo "Building package to verify..."
nix build "$script_dir/../.."#amp

echo "Update completed successfully!"
echo "amp has been updated from $current_version to $latest_version"
