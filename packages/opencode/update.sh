#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Cleanup function
cleanup() {
  if [ -n "${tmp_file:-}" ] && [ -f "$tmp_file" ]; then
    rm -f "$tmp_file"
  fi
  if [ -n "${build_log:-}" ] && [ -f "$build_log" ]; then
    rm -f "$build_log"
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Fetch latest version from GitHub API
echo "Fetching latest version..."
latest_version=$(curl -s https://api.github.com/repos/sst/opencode/releases/latest | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$latest_version" ]; then
  echo "Error: Failed to fetch latest version from GitHub API"
  exit 1
fi

echo "Latest version: $latest_version"

# Extract current version using nix eval
current_version=$(nix eval .#opencode.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Version is already up to date at $current_version"
  echo "Skipping hash verification for up-to-date version"
  exit 0
else
  echo "Update available: $current_version -> $latest_version"
fi

# Create temporary file for updated content
tmp_file=$(mktemp)
cp "$package_file" "$tmp_file"

# Update version
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$tmp_file"

echo "Calculating source hash..."
# Calculate hash for the GitHub source
source_hash=$(nix-prefetch-url --unpack "https://github.com/sst/opencode/archive/refs/tags/v${latest_version}.tar.gz" 2>/dev/null)

if [ -z "$source_hash" ]; then
  echo "Error: Failed to calculate source hash"
  exit 1
fi

# Convert to SRI format
source_hash_sri=$(nix hash to-sri --type sha256 "$source_hash")
echo "Source hash: $source_hash_sri"

# Update source hash in package.nix
sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${source_hash_sri}\";|" "$tmp_file"

echo "Calculating node_modules hash..."
# First, apply the temporary changes to allow building with new version
mv "$tmp_file" "$package_file"

# Build node_modules and capture output
build_log=$(mktemp)
if nix build --log-format bar-with-logs ".#opencode.node_modules" 2>&1 | tee "$build_log"; then
  # Build succeeded, hash was already correct
  node_modules_hash=$(nix eval --raw ".#opencode.node_modules.outputHash")
  echo "node_modules hash was already correct: $node_modules_hash"
else
  # Build failed due to hash mismatch, extract the actual hash
  node_modules_hash=$(grep 'got:' "$build_log" | head -1 | sed -E 's/.*got:[[:space:]]+([^[:space:]]+).*/\1/')

  if [ -z "$node_modules_hash" ]; then
    echo "Error: Failed to extract node_modules hash"
    cat "$build_log"
    exit 1
  fi

  echo "node_modules hash: $node_modules_hash"

  # Update node_modules outputHash in package.nix
  sed -i "s|outputHash = \"sha256-[^\"]*\";|outputHash = \"${node_modules_hash}\";|" "$package_file"
fi

echo "Update completed successfully!"
echo "opencode has been updated from $current_version to $latest_version"
