#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"

# Function to fetch latest version from GitHub releases
fetch_latest_version() {
  # Use GitHub API to get the latest release tag
  curl -s \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/editor-code-assistant/eca/releases/latest |
    jq -r '.tag_name'
}

# Fetch latest version
echo "Fetching latest version from GitHub releases..."
latest_version=$(fetch_latest_version)

# Remove 'v' prefix if present
latest_version="${latest_version#v}"
echo "Latest version: $latest_version"

# Extract current version from package.nix
current_version=$(nix eval .#eca.version --raw)
echo "Current version: $current_version"

# Check if update is needed
if [ "$latest_version" = "$current_version" ]; then
  echo "Package is already up to date!"
  exit 0
fi

echo "Update available: $current_version -> $latest_version"

# Calculate hashes for all platforms
echo "Calculating hashes for all platforms..."

# Create temporary file for updated content
tmp_file=$(mktemp)
cp "$package_file" "$tmp_file"

# Update version
sed -i "s/version = \"${current_version}\";/version = \"${latest_version}\";/" "$tmp_file"

# Platform-specific URLs and hash calculation
declare -A platforms=(
  ["x86_64-linux"]="https://github.com/editor-code-assistant/eca/releases/download/${latest_version}/eca-native-linux-amd64.zip"
  ["aarch64-linux"]="https://github.com/editor-code-assistant/eca/releases/download/${latest_version}/eca-native-linux-aarch64.zip"
  ["x86_64-darwin"]="https://github.com/editor-code-assistant/eca/releases/download/${latest_version}/eca-native-macos-amd64.zip"
  ["aarch64-darwin"]="https://github.com/editor-code-assistant/eca/releases/download/${latest_version}/eca-native-macos-aarch64.zip"
)

for platform in "${!platforms[@]}"; do
  url="${platforms[$platform]}"
  echo "  Calculating hash for $platform..."

  # Use nix-build to automatically get the correct hash
  export NIX_PATH=nixpkgs=flake:nixpkgs

  # All platforms now use native binary zip files
  hash_output=$(nix-build -E "with import <nixpkgs> {}; fetchzip { url = \"${url}\"; sha256 = \"\"; }" 2>&1 || true)

  new_hash=$(echo "$hash_output" | grep "got:" | awk '{print $2}')

  if [ -z "$new_hash" ]; then
    echo "    ERROR: Failed to calculate hash for $platform"
    echo "    Output: $hash_output"
    continue
  fi

  # Update the specific hash for this platform
  # Find the line number for this platform's hash
  line_num=$(grep -n "system = \"$platform\"" "$tmp_file" | cut -d: -f1)
  if [ -n "$line_num" ]; then
    # Find the next hash = line after the system declaration
    # Look for the pattern in the rest of the file from the system declaration
    hash_line=$(tail -n "+$line_num" "$tmp_file" | grep -n "hash = " | head -1 | cut -d: -f1)
    if [ -n "$hash_line" ]; then
      actual_line=$((line_num + hash_line - 1))
      sed -i "${actual_line}s|hash = \"[^\"]*\";|hash = \"${new_hash}\";|" "$tmp_file"
      echo "    $platform: $new_hash"
    else
      echo "    WARNING: Could not find hash line for $platform"
    fi
  else
    # If not found in platform-specific section, try to find JAR version hash
    jar_line=$(grep -n "eca.jar" "$tmp_file" | head -1 | cut -d: -f1)
    if [ -n "$jar_line" ]; then
      # Find the hash line near the JAR file URL
      hash_line=$(tail -n "+$jar_line" "$tmp_file" | grep -n "hash = " | head -1 | cut -d: -f1)
      if [ -n "$hash_line" ]; then
        actual_line=$((jar_line + hash_line - 1))
        sed -i "${actual_line}s|hash = \"[^\"]*\";|hash = \"${new_hash}\";|" "$tmp_file"
        echo "    JAR version: $new_hash"
      else
        echo "    WARNING: Could not find hash line for JAR version"
      fi
    else
      echo "    WARNING: Could not find platform or JAR section for $platform"
    fi
  fi
done

# Check if any changes were made
if ! diff -q "$tmp_file" "$package_file" >/dev/null 2>&1; then
  # Move updated file back
  mv "$tmp_file" "$package_file"

  echo "Building package to verify..."
  nix build .#eca

  echo "Update completed successfully!"
  echo "eca has been updated from $current_version to $latest_version"
else
  echo "No changes needed - all hashes are already correct"
  rm -f "$tmp_file"
fi
