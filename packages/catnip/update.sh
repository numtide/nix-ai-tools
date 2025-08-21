#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get the latest version from GitHub API
latest_version=$(curl -s https://api.github.com/repos/wandb/catnip/releases/latest | jq -r '.tag_name' | sed 's/^v//')

echo "Latest version: $latest_version"

# Update the version in package.nix
sed -i "s/version = \"[^\"]*\"/version = \"$latest_version\"/" package.nix

# Function to get and update hash for a specific platform
update_hash() {
  local platform=$1
  local url_pattern=$2

  echo "Fetching hash for $platform..."
  # shellcheck disable=SC2016
  url="${url_pattern//\${version/}/$latest_version}"

  # Use nix-prefetch-url to get the correct hash
  hash=$(nix-prefetch-url "$url" 2>/dev/null || echo "")

  if [ -n "$hash" ]; then
    sri_hash=$(nix hash to-sri --type sha256 "$hash")
    # Update the hash in package.nix for this platform
    sed -i "/$platform = {/,/};/{s|hash = \"sha256-[^\"]*\"|hash = \"$sri_hash\"|}" package.nix
    echo "Updated $platform hash: $sri_hash"
  else
    echo "Warning: Could not fetch hash for $platform"
  fi
}

# Update hashes for all platforms
# shellcheck disable=SC2016
update_hash "x86_64-linux" 'https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_linux_amd64.tar.gz'
# shellcheck disable=SC2016
update_hash "aarch64-linux" 'https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_linux_arm64.tar.gz'
# shellcheck disable=SC2016
update_hash "x86_64-darwin" 'https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_darwin_amd64.tar.gz'
# shellcheck disable=SC2016
update_hash "aarch64-darwin" 'https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_darwin_arm64.tar.gz'

echo "Update complete!"
