#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Function to fetch latest version from GitHub releases
fetch_latest_version() {
  # Use GitHub API to get the latest release tag
  curl -s \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/editor-code-assistant/eca/releases/latest | \
    jq -r '.tag_name'
}

# Fetch latest version
echo "Fetching latest version from GitHub releases..."
latest_version=$(fetch_latest_version)

# Remove 'v' prefix if present
latest_version="${latest_version#v}"
echo "Latest version: $latest_version"

# Extract current version from package.nix
current_version=$(nix eval .#eca.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Calculate new source hash
echo "Calculating source hash for new version..."
url="https://github.com/editor-code-assistant/eca/releases/download/v${latest_version}/eca.jar"
new_src_hash=$(nix-prefetch-url "$url" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "New source hash: $new_src_hash"

# Update version and source hash in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Extract old hash and replace it
old_src_hash=$(grep -A2 'src = fetchurl' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|$old_src_hash|$new_src_hash|" "$package_file"

echo "Building package to verify..."
nix build .#eca

echo "Update completed successfully!"
echo "eca has been updated from $current_version to $latest_version"