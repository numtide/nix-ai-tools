#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git
# shellcheck shell=bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FILE="$ROOT/packages/catnip/package.nix"

VERSION=$(curl -s https://api.github.com/repos/wandb/catnip/releases/latest | jq -r .tag_name | sed 's/^v//')

fetch_hash() {
  nix store prefetch-file --hash-type sha256 \
    "https://github.com/wandb/catnip/releases/download/v${VERSION}/catnip_${VERSION}_$1.tar.gz" --json | jq -r .hash
}

sed -i "s/version = \".*\"/version = \"$VERSION\"/" "$FILE"

sed -i "/x86_64-linux = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash linux_amd64)\"|" "$FILE"
sed -i "/aarch64-linux = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash linux_arm64)\"|" "$FILE"
sed -i "/x86_64-darwin = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash darwin_amd64)\"|" "$FILE"
sed -i "/aarch64-darwin = {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash darwin_arm64)\"|" "$FILE"

echo "Updated catnip to $VERSION"
