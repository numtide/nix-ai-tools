#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"
lock_file="$script_dir/package-lock.json"

# Cleanup function
cleanup() {
  if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @google/gemini-cli version)
echo "Latest version: $latest_version"

# Extract current version using nix eval
current_version=$(nix eval .#gemini-cli.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Download and extract the npm package to generate package-lock.json
echo "Downloading npm package..."
tmp_dir=$(mktemp -d)
cd "$tmp_dir"
npm pack "@google/gemini-cli@$latest_version" >/dev/null 2>&1
tar -xzf "google-gemini-cli-${latest_version}.tgz"

# Generate package-lock.json
echo "Generating package-lock.json..."
cd package
npm install --package-lock-only --ignore-scripts >/dev/null 2>&1

# Copy the generated package-lock.json
cp package-lock.json "$lock_file"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Step 1: Update URL and set dummy tarball hash
echo "Getting tarball hash..."
sed -i "s|/@google/gemini-cli/-/gemini-cli-[0-9.]\\+\\.tgz|/@google/gemini-cli/-/gemini-cli-${latest_version}.tgz|" "$package_file"
sed -i '/fetchurl {/,/}/ s|hash = "sha256-[^"]*"|hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' "$package_file"

# Build to get the correct tarball hash
if output=$(nix build "$script_dir/../.."#packages.x86_64-linux.gemini-cli 2>&1); then
  echo "ERROR: Build succeeded with dummy tarball hash!"
  exit 1
else
  # Extract the correct hash
  if tarball_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | head -1 | sed 's/.*got: *//' | xargs); then
    echo "Tarball hash: $tarball_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$tarball_hash|" "$package_file"
  else
    echo "ERROR: Could not extract tarball hash from build output"
    exit 1
  fi
fi

# Step 2: Build with wrong npmDeps hash to get the correct one
echo "Getting npmDeps hash..."
# Set a dummy hash for npmDeps
sed -i '/npmDeps = fetchNpmDeps {/,/}/ s|hash = "sha256-[^"]*"|hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' "$package_file"

# Build and capture the correct hash
if output=$(nix build "$script_dir/../.."#packages.x86_64-linux.gemini-cli 2>&1); then
  echo "ERROR: Build succeeded with dummy npmDeps hash!"
  exit 1
else
  # Extract the correct hash
  if npmdeps_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got: *//' | xargs); then
    echo "npmDeps hash: $npmdeps_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$npmdeps_hash|" "$package_file"
  else
    echo "ERROR: Could not extract npmDeps hash from build output"
    exit 1
  fi
fi

# Final verification build
echo "Building package to verify..."
if nix build "$script_dir/../.."#packages.x86_64-linux.gemini-cli; then
  echo "Update completed successfully!"
  echo "gemini-cli has been updated from $current_version to $latest_version"
else
  echo "ERROR: Final build failed!"
  exit 1
fi
