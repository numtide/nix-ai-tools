#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Fetch latest version from npm
echo "Fetching latest version..."
latest_version=$(npm view @kilocode/cli version)
echo "Latest version: $latest_version"

# Extract current version using nix eval
current_version=$(nix eval .#kilo-code.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Extract npm-shrinkwrap.json from the package tarball
echo "Extracting npm-shrinkwrap.json from package..."
temp_dir=$(mktemp -d)
trap "rm -rf '$temp_dir'" EXIT
curl -sL "https://registry.npmjs.org/@kilocode/cli/-/cli-${latest_version}.tgz" | tar xz -C "$temp_dir"
if [ -f "$temp_dir/package/npm-shrinkwrap.json" ]; then
  cp "$temp_dir/package/npm-shrinkwrap.json" "$script_dir/package-lock.json"
  echo "Updated package-lock.json from npm-shrinkwrap.json"
else
  echo "ERROR: npm-shrinkwrap.json not found in package"
  exit 1
fi

# Calculate new source hash
echo "Calculating source hash for new version..."
new_src_hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@kilocode/cli/-/cli-${latest_version}.tgz" 2>&1 | tail -1 | xargs -I {} nix hash to-sri --type sha256 {})
echo "New source hash: $new_src_hash"

# Update version and source hash in package.nix
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$package_file"
old_src_hash=$(grep -A2 'src = fetchzip' "$package_file" | grep 'hash = ' | sed -E 's/.*hash = "([^"]+)".*/\1/')
sed -i "s|$old_src_hash|$new_src_hash|" "$package_file"

echo "Updated version and source hash. Now calculating npmDeps hash..."

# Set a dummy hash for npmDeps to trigger the error with the correct hash
awk '
  /npmDeps = fetchNpmDeps/ { in_npmDeps=1 }
  in_npmDeps && /hash = / {
    sub(/hash = "sha256-[^"]*"/, "hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"")
    in_npmDeps=0
  }
  { print }
' "$package_file" >"$package_file.tmp" && mv "$package_file.tmp" "$package_file"

# Try to build and capture the correct npmDeps hash from the error message
echo "Building to get correct npmDeps hash..."
if ! npm_deps_output=$(nix build "$script_dir/../.."#kilo-code 2>&1); then
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
    exit 1
  fi
else
  echo "Build succeeded unexpectedly with dummy hash!"
  exit 1
fi

echo "Building package to verify..."
nix build "$script_dir/../.."#kilo-code

echo "Update completed successfully!"
echo "kilo-code has been updated from $current_version to $latest_version"
