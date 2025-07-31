#!/usr/bin/env bash
set -euo pipefail

# Change to the repository root directory
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Use nix-update with stable version pattern only
echo "Updating crush package..."
exec nix-update --flake --version=stable crush
