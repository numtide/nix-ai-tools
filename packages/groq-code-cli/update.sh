#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get latest commit info from GitHub API (no releases/tags yet)
latest_commit=$(curl -s https://api.github.com/repos/build-with-groq/groq-code-cli/commits | jq -r '.[0] | .sha')
latest_date=$(curl -s https://api.github.com/repos/build-with-groq/groq-code-cli/commits | jq -r '.[0] | .commit.author.date' | cut -d'T' -f1)

if [ -z "$latest_commit" ]; then
  echo "ERROR: Could not fetch latest commit"
  exit 1
fi

echo "Latest commit: $latest_commit"
echo "Latest date: $latest_date"

# Get version from package.json in the repository
package_version=$(curl -s "https://raw.githubusercontent.com/build-with-groq/groq-code-cli/$latest_commit/package.json" | jq -r '.version')

if [ -z "$package_version" ]; then
  echo "ERROR: Could not fetch version from package.json"
  exit 1
fi

# Create version string
version="$package_version-unstable-$latest_date"
echo "Version: $version"

# Update version and rev in package.nix
sed -i "s/version = \".*\"/version = \"$version\"/" package.nix
sed -i "s/rev = \".*\"/rev = \"$latest_commit\"/" package.nix

# Get source hash using nix-prefetch-url
echo "Getting source hash..."
tarball_url="https://github.com/build-with-groq/groq-code-cli/archive/$latest_commit.tar.gz"
src_hash_raw=$(nix-prefetch-url --unpack "$tarball_url" 2>/dev/null)

if [ -z "$src_hash_raw" ]; then
  echo "ERROR: Could not fetch source hash"
  exit 1
fi

# Convert to SRI format
src_hash=$(nix hash to-sri --type sha256 "$src_hash_raw")
echo "Source hash: $src_hash"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$src_hash\"|" package.nix

# Download and update package.json and package-lock.json
echo "Updating package.json and package-lock.json..."
curl -sL "https://raw.githubusercontent.com/build-with-groq/groq-code-cli/$latest_commit/package.json" -o package.json

# Generate new package-lock.json
rm -f package-lock.json
npm install --package-lock-only

# Set dummy npm deps hash to get the real one
sed -i 's|npmDepsHash = "sha256-[^"]*"|npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' package.nix

# Build to get the correct npm deps hash
echo "Building to get npm deps hash..."
if output=$(nix build ../..#groq-code-cli 2>&1); then
  echo "Build succeeded with dummy hash - checking if it still works"
else
  # Extract the correct npm deps hash
  if npm_hash=$(echo "$output" | grep -A2 "error: hash mismatch" | grep "got:" | sed 's/.*got:[[:space:]]*//' | head -1); then
    echo "NPM deps hash: $npm_hash"
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$npm_hash|" package.nix
  else
    echo "ERROR: Could not extract npm deps hash from build output"
    echo "Build output:"
    echo "$output" | tail -50
    exit 1
  fi
fi

echo "Update complete for groq-code-cli $version!"

# Test the build
echo "Testing final build..."
if nix build ../..#groq-code-cli; then
  echo "✓ Build successful!"
  if [ -f result/bin/groq ]; then
    version_output=$(result/bin/groq --version 2>&1 || true)
    echo "✓ Binary version: $version_output"
  fi
else
  echo "⚠ Build failed - manual intervention may be required"
fi
