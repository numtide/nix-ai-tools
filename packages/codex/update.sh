#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Fetch the latest release info
echo "Fetching latest release info..."
release_info=$(curl -s https://api.github.com/repos/openai/codex/releases/latest)

# Extract version from tag name (removes 'rust-v' prefix)
version=$(echo "$release_info" | jq -r '.tag_name' | sed 's/^rust-v//')

echo "Latest version: $version"

# Update version in package.nix
sed -i "s/version = \"[^\"]*\"/version = \"$version\"/" package.nix

# Download and calculate hashes for each platform
declare -A platforms=(
  ["x86_64-linux"]="codex-x86_64-unknown-linux-musl.tar.gz"
  ["aarch64-linux"]="codex-aarch64-unknown-linux-musl.tar.gz"
  ["x86_64-darwin"]="codex-x86_64-apple-darwin.tar.gz"
  ["aarch64-darwin"]="codex-aarch64-apple-darwin.tar.gz"
)

for platform in "${!platforms[@]}"; do
  filename="${platforms[$platform]}"
  url="https://github.com/openai/codex/releases/download/rust-v${version}/${filename}"

  echo "Calculating hash for ${platform}..."
  hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | xargs nix hash to-sri --type sha256)

  # Update hash in package.nix
  sed -i "/${platform} = {/,/};/s|hash = \"sha256-[^\"]*\"|hash = \"$hash\"|" package.nix
done

echo "Update complete!"
