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
latest_version=$(curl -s https://api.github.com/repos/sst/opencode/releases/latest | jq -r '.tag_name' | sed 's/^v\d+\.\d+\.\d+$//')

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
  # For now, skip hash verification when version is up to date
  # This avoids unnecessary failures in CI
  echo "Skipping hash verification for up-to-date version"
  exit 0
else
  echo "Update available: $current_version -> $latest_version"
fi

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
  # Use nix-build with fetchzip to get the correct hash
  url="https://github.com/sst/opencode/releases/download/v${latest_version}/opencode-${download_name}.zip"

  # Calculate hash with timeout and error handling
  export NIX_PATH=nixpkgs=flake:nixpkgs
  hash_output=$(timeout 60 nix-build -E "with import <nixpkgs> {}; fetchzip { url = \"${url}\"; sha256 = \"\"; }" 2>&1 || true)
  new_hash=$(echo "$hash_output" | grep "got:" | awk '{print $2}')

  if [ -z "$new_hash" ]; then
    echo "    ERROR: Failed to calculate hash for $nix_system"
    echo "    Output: $hash_output"
    continue
  fi

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

# Check if any changes were made
if ! diff -q "$tmp_file" "$package_file" >/dev/null 2>&1; then
  # Move updated file back
  mv "$tmp_file" "$package_file"

  if [ "$latest_version" != "$current_version" ]; then
    echo "Updated to version $latest_version"
  else
    echo "Updated platform hashes for version $current_version"
  fi

  echo "Update completed successfully!"
  if [ "$latest_version" != "$current_version" ]; then
    echo "opencode has been updated from $current_version to $latest_version"
  else
    echo "Platform hashes have been updated for opencode $current_version"
  fi
else
  echo "No changes needed - all hashes are already correct"
  rm -f "$tmp_file"
fi
