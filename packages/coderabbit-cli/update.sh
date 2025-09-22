#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION=$(curl -fsSL https://cli.coderabbit.ai/releases/latest/VERSION | tr -d '[:space:]')
echo "Updating to version $VERSION..."

sed -i "s/version = \".*\"/version = \"$VERSION\"/" package.nix

for platform in x86_64-linux:linux-x64 aarch64-linux:linux-arm64 x86_64-darwin:darwin-x64 aarch64-darwin:darwin-arm64; do
  nix_platform=${platform%:*}
  file_platform=${platform#*:}
  url="https://cli.coderabbit.ai/releases/${VERSION}/coderabbit-${file_platform}.zip"
  hash=$(nix --extra-experimental-features 'nix-command flakes' store prefetch-file --json "$url" | jq -r .hash)
  sed -i "/$nix_platform = {/,/};/ s|hash = \".*\"|hash = \"$hash\"|" package.nix
done

echo "Done! Version $VERSION"
