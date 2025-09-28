#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"/../..

nix run --inputs-from . nixpkgs#nix-update -- \
  --flake \
  --version-regex "^rust-v(\d+\.\d+\.\d+)$" \
  codex
