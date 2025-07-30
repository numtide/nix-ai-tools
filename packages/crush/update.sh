#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Get the latest version from GitHub
latest_version=$(curl -s https://api.github.com/repos/charmbracelet/crush/releases/latest | jq -r .tag_name | sed 's/^v//')

# Update the version in package.nix
sed -i "s/version = \".*\";/version = \"$latest_version\";/" package.nix

# Clear the hashes to trigger nix to fetch them
sed -i 's/hash = "sha256-[^"]*";/hash = "sha256-0000000000000000000000000000000000000000000=";/' package.nix
sed -i 's/vendorHash = "sha256-[^"]*";/vendorHash = "sha256-0000000000000000000000000000000000000000000=";/' package.nix

echo "Updated crush to version $latest_version"
echo "Now run 'nix build .#crush' twice to get the correct hashes"
