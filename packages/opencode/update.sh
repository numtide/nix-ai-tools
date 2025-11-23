#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$script_dir/package.nix"
cd "$script_dir/../.."

echo "Updating opencode package..."

# Step 1: Update the main package version and source hash
echo "Updating opencode version and source hash..."
nix run nixpkgs#nix-update -- --flake opencode

# Check if there were changes
if ! git diff --quiet "$package_file"; then
  echo "Package version and source hash updated"
  
  # Step 2: Update node_modules hash
  echo "Updating node_modules hash..."
  
  # Get the current node_modules hash (the outputHash within the node_modules derivation)
  # We look for the line after "node_modules = " up to the closing brace to find the right outputHash
  old_node_hash=$(awk '/node_modules = stdenvNoCC\.mkDerivation/,/^  \};/ { if (/^\s*outputHash = "sha256-/) { print $0; exit } }' "$package_file" | sed -E 's/.*outputHash = "([^"]+)".*/\1/')
  
  if [ -z "$old_node_hash" ]; then
    echo "ERROR: Could not find node_modules outputHash"
    exit 1
  fi
  
  # Replace with dummy hash to trigger rebuild
  sed -i "s|$old_node_hash|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|" "$package_file"
  
  # Try to build and capture the correct hash
  echo "Building to get correct node_modules hash..."
  if output=$(nix build .#opencode 2>&1); then
    echo "Build succeeded unexpectedly with dummy hash!"
    # Restore original hash as a fallback
    sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$old_node_hash|" "$package_file"
  else
    # Extract the correct hash from error output
    # Look for the pattern "got:    sha256-..." in the output
    new_node_hash=$(echo "$output" | grep -E "got:[[:space:]]+sha256-" | sed -E 's/.*got:[[:space:]]+(sha256-[^[:space:]]+).*/\1/' | head -n1)
    if [ -n "$new_node_hash" ]; then
      echo "New node_modules hash: $new_node_hash"
      sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$new_node_hash|" "$package_file"
    else
      echo "ERROR: Could not extract node_modules hash from build output"
      echo "Build output:"
      echo "$output" | tail -20
      # Restore original hash
      sed -i "s|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|$old_node_hash|" "$package_file"
      exit 1
    fi
  fi
  
  echo "Verifying build with new hash..."
  nix build .#opencode
  
  echo "Update completed successfully!"
else
  echo "No changes detected, package is already up to date"
fi
