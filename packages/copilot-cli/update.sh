#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for cmd in curl jq nix-prefetch-url npm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $cmd" >&2
    exit 1
  fi
done

sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

registry_url="https://registry.npmjs.org/@github%2Fcopilot"
version=$(curl -s "$registry_url" | jq -r '."dist-tags".latest')

if [[ -z $version || $version == "null" ]]; then
  echo "ERROR: unable to determine latest version" >&2
  exit 1
fi

tarball_url="https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz"
raw_hash=$(nix-prefetch-url "$tarball_url")
source_hash=$(nix hash to-sri --type sha256 "$raw_hash")

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -sL "$tarball_url" -o "$tmpdir/copilot.tgz"
tar -xzf "$tmpdir/copilot.tgz" -C "$tmpdir"

pushd "$tmpdir/package" >/dev/null
npm install --ignore-scripts --package-lock-only
cp package-lock.json "$OLDPWD/package-lock.json"
popd >/dev/null

npm_hash=$(nix run --inputs-from . nixpkgs#prefetch-npm-deps -- ./package-lock.json)

sed_inplace "s/version = \".*\";/version = \"$version\";/" package.nix
sed_inplace "s|hash = \"sha256-[^\"]*\";|hash = \"$source_hash\";|" package.nix
sed_inplace "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$npm_hash\";|" package.nix

echo "Updated copilot-cli to $version"
