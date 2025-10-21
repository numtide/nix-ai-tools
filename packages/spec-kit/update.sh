#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for cmd in curl jq nix-prefetch-git; do
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

# Get latest commit from main branch
latest_commit=
latest_commit=$(curl -s "https://api.github.com/repos/github/spec-kit/commits/main" | jq -r '.sha')

if [[ -z $latest_commit || $latest_commit == "null" ]]; then
  echo "ERROR: unable to determine latest commit" >&2
  exit 1
fi

echo "Latest commit: $latest_commit"

# Get version from pyproject.toml
version=
version=$(curl -s "https://raw.githubusercontent.com/github/spec-kit/$latest_commit/pyproject.toml" | grep '^version' | cut -d'"' -f2)

if [[ -z $version || $version == "null" ]]; then
  echo "ERROR: unable to determine version" >&2
  exit 1
fi

echo "Version: $version"

# Get the hash for the source
hash_output=
hash_output=$(nix-prefetch-git --quiet --url "https://github.com/github/spec-kit" --rev "$latest_commit" 2>&1)
source_hash=
source_hash=$(echo "$hash_output" | jq -r '.hash')

if [[ -z $source_hash || $source_hash == "null" ]]; then
  echo "ERROR: unable to determine source hash" >&2
  exit 1
fi

echo "Source hash: $source_hash"

# Update package.nix
sed_inplace "s/version = \".*\";/version = \"$version\";/" package.nix
sed_inplace "s/rev = \".*\";/rev = \"$latest_commit\";/" package.nix
sed_inplace "s|hash = .*;|hash = \"$source_hash\";|" package.nix

echo "Updated spec-kit to $version (commit: ${latest_commit:0:7})"
