#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git
# shellcheck shell=bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FILE="$ROOT/packages/handy/package.nix"

VERSION=$(curl -s https://api.github.com/repos/cjpais/Handy/releases/latest | jq -r .tag_name | sed 's/^v//')

fetch_hash() {
  nix store prefetch-file --hash-type sha256 \
    "https://github.com/cjpais/Handy/releases/download/v${VERSION}/$1" --json | jq -r .hash
}

sed -i "s/version = \".*\"/version = \"$VERSION\"/" "$FILE"

# Update x86_64-linux (deb)
sed -i "/x86_64-linux = fetchurl {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash "Handy_${VERSION}_amd64.deb")\"|" "$FILE"

# Update x86_64-darwin (app.tar.gz)
sed -i "/x86_64-darwin = fetchurl {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash "Handy_x64.app.tar.gz")\"|" "$FILE"

# Update aarch64-darwin (app.tar.gz)
sed -i "/aarch64-darwin = fetchurl {/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"$(fetch_hash "Handy_aarch64.app.tar.gz")\"|" "$FILE"

echo "Updated handy to $VERSION"
