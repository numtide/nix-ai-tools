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
}

# Set up cleanup trap
trap cleanup EXIT

# Fetch latest version from GitHub API
echo "Fetching latest version..."
latest_version=$(curl -s https://api.github.com/repos/sst/opencode/releases/latest | jq -r '.tag_name' | sed 's/^v//')
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

# Calculate hashes for all platforms
echo "Calculating hashes for all platforms..."

# Create temporary file for updated content
tmp_file=$(mktemp)
cp "$package_file" "$tmp_file"

# Update version
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$tmp_file"

# Update hashes for each platform
declare -A platforms=(
  ["x86_64-linux"]="linux-x64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-darwin"]="darwin-x64"
  ["aarch64-darwin"]="darwin-arm64"
)

for nix_system in "${!platforms[@]}"; do
  download_name="${platforms[$nix_system]}"
  echo "  Calculating hash for $nix_system..."
  new_hash=$(nix hash file --sri <(curl -sL "https://github.com/sst/opencode/releases/download/v${latest_version}/opencode-${download_name}.zip"))

  # Update the specific hash for this platform
  # Find the line number for this platform's hash
  line_num=$(grep -n "$nix_system = {" "$tmp_file" | cut -d: -f1)
  if [ -n "$line_num" ]; then
    # Find the sha256 line after the platform declaration (within next 3 lines)
    sha_line=$((line_num + 2))
    sed -i "${sha_line}s|sha256 = \"[^\"]*\";|sha256 = \"${new_hash}\";|" "$tmp_file"
    echo "    $nix_system: $new_hash"
  fi
done

# Move updated file back
mv "$tmp_file" "$package_file"

echo "Updated to version $latest_version"
echo "Building package to verify..."
nix build "$script_dir/../.."#packages.x86_64-linux.opencode

echo "Update completed successfully!"
echo "opencode has been updated from $current_version to $latest_version"
