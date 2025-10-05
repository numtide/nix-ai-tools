#!/usr/bin/env bash
set -xeuo pipefail

script_dir="$(dirname "${BASH_SOURCE[0]}")"
cd "$script_dir"

latest_version=$(npm view @qwen-code/qwen-code version)

(
  trap "rm -rf package.json package" EXIT

  echo "Fetching latest version..."

  echo "Downloading package.json from tarball..."
  npm pack @qwen-code/qwen-code@"$latest_version"
  tar -xzf qwen-code-qwen-code-"$latest_version".tgz package/package.json
  mv package/package.json .
  rm -rf package qwen-code-qwen-code-"$latest_version".tgz

  echo "Updating package-lock.json..."
  npm i --package-lock-only

  echo "Running nix-update..."
)
cd ../..
nix run --inputs-from . nixpkgs#nix-update -- --flake --version "$latest_version" qwen-code
