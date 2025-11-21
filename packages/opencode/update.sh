#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/../.."

echo "Updating opencode package..."

# Step 1: Update the main package version and source hash
echo "Updating opencode version and source hash..."
nix run nixpkgs#nix-update -- --flake opencode

# Step 2: Update node_modules hash
echo "Updating node_modules hash..."
nix run nixpkgs#nix-update -- --flake --version=skip opencode.node_modules
