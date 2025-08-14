#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @sourcegraph/amp version)
echo "Latest version: $latest_version"

# Extract current version from package.nix
current_version=$(grep -Po 'version = "\K[^"]+' "$package_file")
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Update version in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"

# Update URL
sed -i "s|/@sourcegraph/amp/-/amp-[^/]\\+\\.tgz|/@sourcegraph/amp/-/amp-${latest_version}.tgz|" "$package_file"

# Get new source hash
echo "Getting new source hash..."
new_hash=$(nix-prefetch-url "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${latest_version}.tgz" | tail -1)
new_sri_hash=$(nix hash to-sri --type sha256 "$new_hash")

# Update only the fetchurl hash (it comes after the url line)
# Find line with fetchurl hash and update it specifically
awk -v new_hash="$new_sri_hash" '
  /url = "https:\/\/registry\.npmjs\.org\/@sourcegraph\/amp/ { found=1 }
  found && /hash = / {
    sub(/hash = "sha256-[^"]*"/, "hash = \"" new_hash "\"")
    found=0
  }
  { print }
' "$package_file" >"$package_file.tmp" && mv "$package_file.tmp" "$package_file"

# Generate package-lock.json from the new package.json
echo "Generating package-lock.json from new version..."
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Extract the tarball
curl -sL "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${latest_version}.tgz" | tar -xz -C "$temp_dir"

# Check if package-lock.json exists in the tarball
if [ -f "$temp_dir/package/package-lock.json" ]; then
  cp "$temp_dir/package/package-lock.json" "$script_dir/package-lock.json"
  echo "Updated package-lock.json from tarball"
else
  # Generate package-lock.json from package.json
  echo "No package-lock.json in tarball, generating from package.json..."
  cd "$temp_dir/package"
  npm install --package-lock-only --ignore-scripts
  if [ -f "package-lock.json" ]; then
    cp "package-lock.json" "$script_dir/package-lock.json"
    echo "Generated and updated package-lock.json"
  else
    echo "Error: Failed to generate package-lock.json"
    exit 1
  fi
  cd "$script_dir"
fi

echo "Calculating new npmDeps hash..."
# First set a dummy hash to trigger the error with the correct hash
# We need to update only the npmDeps hash, not the fetchurl hash
awk '
  /npmDeps = fetchNpmDeps/ { in_npmDeps=1 }
  in_npmDeps && /hash = / {
    sub(/hash = "sha256-[^"]*"/, "hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"")
    in_npmDeps=0
  }
  { print }
' "$package_file" >"$package_file.tmp" && mv "$package_file.tmp" "$package_file"

# Try to build and capture the correct npmDeps hash from the error message
if ! npm_deps_output=$(nix build "$script_dir/../.."#amp 2>&1); then
  # Extract the correct hash from the error message - looking for the "got:" line
  correct_npm_hash=$(echo "$npm_deps_output" | grep -E "got:[[:space:]]*sha256-" | awk '{print $2}' | head -1)

  if [ -n "$correct_npm_hash" ]; then
    echo "Updating npmDeps hash to: $correct_npm_hash"
    # Update the npmDeps hash specifically
    awk -v new_hash="$correct_npm_hash" '
      /npmDeps = fetchNpmDeps/ { in_npmDeps=1 }
      in_npmDeps && /hash = / {
        sub(/hash = "sha256-[^"]*"/, "hash = \"" new_hash "\"")
        in_npmDeps=0
      }
      { print }
    ' "$package_file" >"$package_file.tmp" && mv "$package_file.tmp" "$package_file"
  else
    echo "Warning: Could not extract npmDeps hash from error output"
    echo "Error output was:"
    echo "$npm_deps_output" | grep -A2 -B2 "hash mismatch" || echo "$npm_deps_output" | tail -20
  fi
fi

echo "Building package to verify..."
nix build "$script_dir/../.."#amp

echo "Update completed successfully!"
echo "amp has been updated from $current_version to $latest_version"
