#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get the latest version from npm
latest_version=$(curl -s https://registry.npmjs.org/@musistudio/claude-code-router | jq -r '.["dist-tags"].latest')

echo "Latest version: $latest_version"

# Update the version in default.nix
sed -i "s/version = \".*\";/version = \"$latest_version\";/" default.nix

# Get the new tarball hash
echo "Fetching new tarball hash..."
new_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-$latest_version.tgz" 2>/dev/null | tail -1)
new_sri_hash=$(nix hash to-sri --type sha256 "$new_hash")

# Update the hash in default.nix
sed -i "s|hash = \"sha256-.*\";|hash = \"$new_sri_hash\";|" default.nix

echo "Updated to version $latest_version with hash $new_sri_hash"
