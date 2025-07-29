#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @qwen-code/qwen-code version)
echo "Latest version: $latest_version"

# Extract current version using nix eval
current_version=$(nix eval .#qwen-code.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Calculate tarball hash
echo "Calculating tarball hash..."
new_tarball_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${latest_version}.tgz" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "New tarball hash: $new_tarball_hash"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Update the tarball URL and hash
sed -i "s|/@qwen-code/qwen-code/-/qwen-code-[0-9a-zA-Z.-]*\.tgz|/@qwen-code/qwen-code/-/qwen-code-${latest_version}.tgz|" "$package_file"
old_tarball_hash=$(grep -B1 -A1 'url = "https://registry.npmjs.org/@qwen-code/qwen-code' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|hash = \"$old_tarball_hash\"|hash = \"$new_tarball_hash\"|" "$package_file"

echo "Building package to verify..."
nix build "$script_dir/../.."#packages.x86_64-linux.qwen-code

echo "Update completed successfully!"
echo "qwen-code has been updated from $current_version to $latest_version"
