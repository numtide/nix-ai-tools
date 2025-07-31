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
if [ "$latest_version" = "$current_version" ] && [ "${FORCE_UPDATE:-}" != "true" ]; then
  echo "Package is already up to date!"
  echo "Use FORCE_UPDATE=true to force hash updates"
  exit 0
fi

if [ "$latest_version" = "$current_version" ]; then
  echo "Forcing hash update for version $current_version"
else
  echo "Update available: $current_version -> $latest_version"
fi

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
# Find the line number with fetchurl hash and replace it
fetchurl_hash_line=$(grep -n "fetchurl {" "$package_file" | cut -d: -f1)
if [ -n "$fetchurl_hash_line" ]; then
  # The hash is usually 2 lines after "fetchurl {"
  hash_line=$((fetchurl_hash_line + 2))
  sed -i "${hash_line}s/hash = \"sha256-[^\"]*\"/hash = \"sha256-0000000000000000000000000000000000000000000=\"/" "$package_file"
fi

# Build to get the correct tarball hash
if output=$(nix build "$script_dir/../.."#gemini-cli 2>&1); then
  echo "ERROR: Build succeeded with dummy tarball hash!"
  exit 1
else
  # Extract the correct hash - look for hash mismatch in .tgz derivation
  if tarball_hash=$(echo "$output" | grep -B1 -A5 "\.tgz\.drv" | grep -A2 "error: hash mismatch" | grep "got:" | head -1 | sed 's/.*got: *//' | xargs); then
    echo "Tarball hash: $tarball_hash"
    sed -i "s|sha256-0000000000000000000000000000000000000000000=|$tarball_hash|" "$package_file"
  else
    echo "ERROR: Could not extract tarball hash from build output"
    echo "Build output:"
    echo "$output" | tail -20
    exit 1
  fi
fi

# Step 2: Build with wrong npmDeps hash to get the correct one
echo "Getting npmDeps hash..."
# Find the line number with npmDeps hash and replace it
npmdeps_hash_line=$(grep -n "npmDeps = fetchNpmDeps {" "$package_file" | cut -d: -f1)
if [ -n "$npmdeps_hash_line" ]; then
  # The hash is usually 2 lines after "npmDeps = fetchNpmDeps {"
  hash_line=$((npmdeps_hash_line + 2))
  sed -i "${hash_line}s/hash = \"sha256-[^\"]*\"/hash = \"sha256-1111111111111111111111111111111111111111111=\"/" "$package_file"
fi

# Build and capture the correct hash
if output=$(nix build "$script_dir/../.."#gemini-cli 2>&1); then
  echo "ERROR: Build succeeded with dummy npmDeps hash!"
  exit 1
else
  # Extract the correct hash - look for npm-deps derivation
  if npmdeps_hash=$(echo "$output" | grep -B1 -A5 "npm-deps\.drv" | grep -A2 "error: hash mismatch" | grep "got:" | head -1 | sed 's/.*got: *//' | xargs); then
    echo "npmDeps hash: $npmdeps_hash"
    sed -i "s|sha256-1111111111111111111111111111111111111111111=|$npmdeps_hash|" "$package_file"
  else
    echo "ERROR: Could not extract npmDeps hash from build output"
    echo "Build output:"
    echo "$output" | tail -20
    exit 1
  fi
fi

echo "Building package to verify..."
nix build "$script_dir/../.."#gemini-cli

echo "Update completed successfully!"
if [ "$latest_version" = "$current_version" ]; then
  echo "Hashes have been updated for gemini-cli $current_version"
else
  echo "gemini-cli has been updated from $current_version to $latest_version"
fi
