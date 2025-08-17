#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Function to extract version from download page
get_latest_version() {
  # Fetch the install script and extract version from download URLs
  curl -s https://cursor.com/install | grep -oE 'downloads\.cursor\.com/lab/[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]+' | head -1 | sed 's|downloads\.cursor\.com/lab/||'
}

# Fetch latest version
echo "Fetching latest version..."
latest_version=$(get_latest_version)
echo "Latest version: $latest_version"

# Extract current version from package.nix
current_version=$(grep -oP '(?<=version = ")[^"]+' "$package_file")
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Function to update hash for a specific platform
update_hash() {
  local os=$1
  local arch=$2
  local platform_key="${arch}-${os}"

  echo "Calculating hash for $platform_key..."

  # Construct URL
  local url="https://downloads.cursor.com/lab/${latest_version}/${os}/${arch}/agent-cli-package.tar.gz"

  # Calculate new hash (no --unpack for tar.gz)
  local new_hash
  new_hash=$(nix-prefetch-url "$url" 2>&1 | tail -1 | xargs -I {} nix hash convert --to sri sha256:{})

  echo "New hash for $platform_key: $new_hash"

  # Map to Nix system format for matching in package.nix
  local nix_system
  case "$platform_key" in
  "x64-linux") nix_system="x86_64-linux" ;;
  "arm64-linux") nix_system="aarch64-linux" ;;
  "x64-darwin") nix_system="x86_64-darwin" ;;
  "arm64-darwin") nix_system="aarch64-darwin" ;;
  esac

  # Update hash in package.nix - find the line after the platform key
  # Use awk to update the hash more reliably
  awk -v key="$nix_system" -v hash="$new_hash" '
    $0 ~ key " = fetchurl {" { found=1 }
    found && /hash = / {
      sub(/hash = "sha256-[^"]*"/, "hash = \"" hash "\"")
      found=0
    }
    { print }
  ' "$package_file" >"$package_file.tmp" && mv "$package_file.tmp" "$package_file"
}

# Update hashes for all platforms
update_hash "linux" "x64"
update_hash "linux" "arm64"
update_hash "darwin" "x64"
update_hash "darwin" "arm64"

echo "Building package to verify..."
nix build .#cursor-agent

echo "Update completed successfully!"
echo "cursor-agent has been updated from $current_version to $latest_version"
