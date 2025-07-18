#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Cleanup function
cleanup() {
  if [ -n "${package_json_created:-}" ] && [ -f "$script_dir/package.json" ]; then
    rm -f "$script_dir/package.json"
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @anthropic-ai/claude-code version)
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

# Generate updated lock file
echo "Updating package-lock.json..."
cd "$script_dir"
package_json_created=1
npm i --package-lock-only @anthropic-ai/claude-code@"$latest_version"

# Calculate new source hash
echo "Calculating source hash for new version..."
new_src_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${latest_version}.tgz" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "New source hash: $new_src_hash"

# Update version and source hash in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"
old_src_hash=$(grep -A1 'src = fetchzip' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|$old_src_hash|$new_src_hash|" "$package_file"

echo "Updated version and source hash. Now building to get new npmDepsHash..."

# Build with dummy hash to get the correct one
old_npm_hash=$(grep 'npmDepsHash = ' "$package_file" | sed -E 's/.*npmDepsHash = "([^"]+)".*/\1/')
sed -i "s|$old_npm_hash|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|" "$package_file"

# Try to build and capture the correct hash
echo "Building to get correct npmDepsHash..."
if output=$(nix build "$script_dir/../.."#packages.x86_64-linux.claude-code 2>&1); then
  echo "Build succeeded unexpectedly with dummy hash!"
else
  # Extract the correct hash from error output
  if new_npm_hash=$(echo "$output" | grep -A1 "got:" | tail -1 | xargs); then
    echo "New npmDepsHash: $new_npm_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$new_npm_hash|" "$package_file"
  else
    echo "ERROR: Could not extract npmDepsHash from build output"
    # Restore original hash
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$old_npm_hash|" "$package_file"
    exit 1
  fi
fi

echo "Building package to verify..."
nix build "$script_dir/../.."#packages.x86_64-linux.claude-code

echo "Update completed successfully!"
echo "claude-code has been updated from $current_version to $latest_version"
