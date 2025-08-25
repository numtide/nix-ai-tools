#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"
lock_file="$script_dir/package-lock.json"

# Cleanup temporary directory
cleanup() {
  if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

# Fetch the latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @qwen-code/qwen-code version)
echo "Latest version: $latest_version"

# Get current version from nix
current_version=$(nix eval .#qwen-code.version --raw)
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

# Download npm package and generate package-lock.json
echo "Downloading npm package..."
tmp_dir=$(mktemp -d)
cd "$tmp_dir"
npm pack "@qwen-code/qwen-code@$latest_version" >/dev/null 2>&1
tarball_name=$(ls ./*.tgz)
tar -xzf "$tarball_name"

echo "Generating package-lock.json..."
cd package
npm install --package-lock-only --ignore-scripts >/dev/null 2>&1
cp package-lock.json "$lock_file"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Step 1: Update tarball URL and set dummy srcHash
echo "Updating tarball URL and dummy srcHash..."
sed -i "s|/@qwen-code/qwen-code/-/qwen-code-[0-9.]\+\.tgz|/@qwen-code/qwen-code/-/qwen-code-${latest_version}.tgz|" "$package_file"
# Replace only srcHash value, keep indentation and semicolon
sed -i 's/srcHash = ".*";/srcHash = "sha256-0000000000000000000000000000000000000000000=";/' "$package_file"

# Build to get correct tarball hash
echo "Building to get correct tarball hash..."
output=$(nix build "$script_dir/../.."#qwen-code 2>&1 || true)
tarball_hash=$(echo "$output" | grep "got:" | head -1 | sed 's/.*got: *//' | xargs)
if [ -n "$tarball_hash" ]; then
  echo "Tarball hash: $tarball_hash"
  sed -i "s|\(srcHash = \"\)[^\"=]*=\(\";\\)|\1$tarball_hash\2|" "$package_file"
else
  echo "ERROR: Could not extract tarball hash from build output"
  echo "$output" | tail -20
  exit 1
fi

# Step 2: Update dummy npmDepsHash
echo "Setting dummy npmDepsHash..."
# Replace only npmDepsHash value, keep indentation and semicolon
sed -i 's/npmDepsHash = ".*";/npmDepsHash = "sha256-1111111111111111111111111111111111111111111=";/' "$package_file"

# Build to get correct npmDeps hash
echo "Building to get correct npmDeps hash..."
output=$(nix build "$script_dir/../.."#qwen-code 2>&1 || true)
npmdeps_hash=$(echo "$output" | grep "got:" | head -1 | sed 's/.*got: *//' | xargs)
if [ -n "$npmdeps_hash" ]; then
  echo "npmDeps hash: $npmdeps_hash"
  sed -i "s|^\(\s*npmDepsHash = \"\)[^\"]*\(\";\)|\1$npmdeps_hash\2|" "$package_file"
else
  echo "ERROR: Could not extract npmDeps hash from build output"
  echo "$output" | tail -20
  exit 1
fi

# Final verification build
echo "Building package to verify..."
nix build "$script_dir/../.."#qwen-code

echo "Update completed successfully!"
if [ "$latest_version" = "$current_version" ]; then
  echo "Hashes have been updated for qwen-code $current_version"
else
  echo "qwen-code has been updated from $current_version to $latest_version"
fi
