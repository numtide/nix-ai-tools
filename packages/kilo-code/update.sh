#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @kilocode/cli version)
echo "Latest version: $latest_version"

# Extract current version using nix eval
current_version=$(nix eval .#kilo-code.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Extract npm-shrinkwrap.json from the package tarball
echo "Extracting npm-shrinkwrap.json from package..."
temp_dir=$(mktemp -d)
trap "rm -rf '$temp_dir'" EXIT
curl -sL "https://registry.npmjs.org/@kilocode/cli/-/cli-${latest_version}.tgz" | tar xz -C "$temp_dir"
if [ -f "$temp_dir/package/npm-shrinkwrap.json" ]; then
  cp "$temp_dir/package/npm-shrinkwrap.json" "$script_dir/package-lock.json"
  echo "Updated package-lock.json from npm-shrinkwrap.json"
else
  echo "ERROR: npm-shrinkwrap.json not found in package"
  exit 1
fi

# Calculate new source hash
echo "Calculating source hash for new version..."
new_src_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@kilocode/cli/-/cli-${latest_version}.tgz" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "New source hash: $new_src_hash"

# Update version and source hash in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"
old_src_hash=$(grep -A2 'src = fetchzip' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|$old_src_hash|$new_src_hash|" "$package_file"

echo "Updated version and source hash. Now building to get new npmDepsHash..."

# Build with dummy hash to get the correct one
old_npm_hash=$(grep 'npmDepsHash = ' "$package_file" | sed -E 's/.*npmDepsHash = "([^"]+)".*/\1/')
sed -i "s|$old_npm_hash|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|" "$package_file"

# Try to build and capture the correct hash
echo "Building to get correct npmDepsHash..."
if output=$(nix build .#kilo-code 2>&1); then
  echo "Build succeeded unexpectedly with dummy hash!"
else
  # Extract the correct hash from error output
  new_npm_hash=$(echo "$output" | grep -E "got:[[:space:]]+sha256-" | sed -E 's/.*got:[[:space:]]+(sha256-[^[:space:]]+).*/\1/' | head -1)
  if [ -n "$new_npm_hash" ] && [ "$new_npm_hash" != "" ]; then
    echo "New npmDepsHash: $new_npm_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$new_npm_hash|" "$package_file"
  else
    echo "ERROR: Could not extract npmDepsHash from build output"
    echo "Build output:"
    echo "$output" | tail -20
    # Restore original hash
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$old_npm_hash|" "$package_file"
    exit 1
  fi
fi

echo "Building package to verify..."
nix build .#kilo-code

echo "Update completed successfully!"
echo "kilo-code has been updated from $current_version to $latest_version"
