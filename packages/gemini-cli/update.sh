#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"
lock_file="$script_dir/package-lock.json"

# Cleanup function
cleanup() {
  if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @google/gemini-cli version)
echo "Latest version: $latest_version"

# Extract current version from package.nix
current_version=$(grep -E '^\s*version = "' "$package_file" | sed -E 's/.*version = "([^"]+)".*/\1/')
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Download and extract the npm package
echo "Downloading npm package..."
tmp_dir=$(mktemp -d)
cd "$tmp_dir"
npm pack "@google/gemini-cli@$latest_version" >/dev/null 2>&1
tar -xzf "google-gemini-cli-${latest_version}.tgz"

# Generate package-lock.json
echo "Generating package-lock.json..."
cd package
npm install --package-lock-only --ignore-scripts >/dev/null 2>&1

# Copy the generated package-lock.json
cp package-lock.json "$lock_file"

# Calculate tarball hash
echo "Calculating tarball hash..."
cd "$tmp_dir"
new_tarball_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-${latest_version}.tgz" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "New tarball hash: $new_tarball_hash"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Update the tarball URL and hash
sed -i "s|/@google/gemini-cli/-/gemini-cli-[0-9.]*\.tgz|/@google/gemini-cli/-/gemini-cli-${latest_version}.tgz|" "$package_file"
old_tarball_hash=$(grep -B1 -A1 'url = "https://registry.npmjs.org/@google/gemini-cli' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|hash = \"$old_tarball_hash\"|hash = \"$new_tarball_hash\"|" "$package_file"

# Cleanup happens automatically via trap

echo "Updated version and tarball hash. Now building to get new npmDeps hash..."

# Build with dummy hash to get the correct one
old_npm_hash=$(grep -A1 'npmDeps = fetchNpmDeps' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|hash = \"$old_npm_hash\"|hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"|" "$package_file"

# Try to build and capture the correct hash
echo "Building to get correct npmDeps hash..."
if output=$(nix build "$script_dir/../.."#packages.x86_64-linux.gemini-cli 2>&1); then
  echo "Build succeeded unexpectedly with dummy hash!"
else
  # Extract the correct hash from error output
  if new_npm_hash=$(echo "$output" | grep -A1 "got:" | tail -1 | xargs); then
    echo "New npmDeps hash: $new_npm_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$new_npm_hash|" "$package_file"
  else
    echo "ERROR: Could not extract npmDeps hash from build output"
    # Restore original hash
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$old_npm_hash|" "$package_file"
    exit 1
  fi
fi

echo "Building package to verify..."
nix build "$script_dir/../.."#packages.x86_64-linux.gemini-cli

echo "Update completed successfully!"
echo "gemini-cli has been updated from $current_version to $latest_version"
