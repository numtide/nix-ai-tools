#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get the latest version from npm
latest_version=$(curl -s https://registry.npmjs.org/@musistudio/claude-code-router | jq -r '.["dist-tags"].latest')
echo "Latest version: $latest_version"

# Extract current version using nix eval
current_version=$(nix eval .#claude-code-router.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Update the version in package.nix
sed -i "s/version = \".*\";/version = \"$latest_version\";/" package.nix

# Get the new tarball hash
echo "Fetching new tarball hash..."
new_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-$latest_version.tgz" 2>/dev/null | tail -1)
new_sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$new_hash")

# Update the hash in package.nix
sed -i "s|hash = \"sha256-.*\";|hash = \"$new_sri_hash\";|" package.nix

echo "Updated to version $latest_version with hash $new_sri_hash"
