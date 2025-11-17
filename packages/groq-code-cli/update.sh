#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix-update

set -euo pipefail

# Update using nix-update with flake attribute path
nix-update --flake --version=branch groq-code-cli
