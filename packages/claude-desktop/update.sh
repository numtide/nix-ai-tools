#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# URLs for Claude Desktop
x64_url="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"
arm64_url="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/Claude-Setup-arm64.exe"

echo "Fetching Claude Desktop installer hashes..."

# Download a small portion to check if files exist and get version info
echo "Checking x64 version..."
if curl -s -r 0-1000 "$x64_url" >/dev/null 2>&1; then
  echo "x64 installer is accessible"
else
  echo "ERROR: Cannot access x64 installer"
  exit 1
fi

echo "Checking arm64 version..."
if curl -s -r 0-1000 "$arm64_url" >/dev/null 2>&1; then
  echo "arm64 installer is accessible"
else
  echo "ERROR: Cannot access arm64 installer"
  exit 1
fi

# Calculate hashes
echo "Calculating x64 hash..."
x64_hash=$(nix-prefetch-url "$x64_url" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "x64 hash: $x64_hash"

echo "Calculating arm64 hash..."
arm64_hash=$(nix-prefetch-url "$arm64_url" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "arm64 hash: $arm64_hash"

# Try to extract version from the installer
echo "Attempting to extract version..."
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Download a small portion of the installer to check version
if command -v 7z >/dev/null 2>&1; then
  echo "Downloading x64 installer to check version..."
  curl -L "$x64_url" -o "$temp_dir/claude-setup.exe" 2>/dev/null || true

  if [ -f "$temp_dir/claude-setup.exe" ]; then
    # Try to extract version from the installer
    version=$(7z l "$temp_dir/claude-setup.exe" 2>/dev/null | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1) || true

    if [ -z "$version" ]; then
      # Try alternative extraction method
      version=$(7z x -y "$temp_dir/claude-setup.exe" -o"$temp_dir/extracted" 2>/dev/null &&
        find "$temp_dir/extracted" -name "AnthropicClaude-*.nupkg" |
        grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1) || true
    fi

    if [ -n "$version" ]; then
      echo "Detected version: $version"
      current_version=$(grep -oP 'version = "\K[^"]+' "$package_file" | head -1)
      if [ "$current_version" != "$version" ]; then
        echo "Updating version from $current_version to $version"
        sed -i "s/version = \"$current_version\"/version = \"$version\"/" "$package_file"
      else
        echo "Version is already up to date"
      fi
    else
      echo "Could not detect version automatically"
    fi
  fi
else
  echo "7z not found, skipping version detection"
fi

# Update hashes in package.nix
echo "Updating package.nix..."

# Update x64 hash
sed -i "/x86_64-linux = fetchurl {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$x64_hash\"|" "$package_file"

# Update arm64 hash
sed -i "/aarch64-linux = fetchurl {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$arm64_hash\"|" "$package_file"

echo "Hashes updated successfully!"
echo ""

echo "Building package to verify..."
nix build .#claude-desktop

# Check if version was updated
if [ -z "${version:-}" ]; then
  echo "Note: Version number needs to be updated manually in package.nix"
  echo "Check https://github.com/aaddrick/claude-desktop-debian/releases for latest version"
else
  echo "Version and hashes have been updated"
fi
