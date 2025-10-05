#!/usr/bin/env bash
set -euo pipefail

platform="$1"

echo "Building node_modules for $platform..."

# Build node_modules and capture output (will fail with hash mismatch on first run)
if nix build --log-format bar-with-logs ".#packages.$platform.opencode.node_modules" 2>&1 | tee build.log; then
  # Build succeeded, hash was already correct
  hash=$(nix eval --raw ".#packages.$platform.opencode.node_modules.outputHash")
else
  # Build failed due to hash mismatch, extract the actual hash
  hash=$(grep 'got:' build.log | head -1 | sed -E 's/.*got:[[:space:]]+([^[:space:]]+).*/\1/')
fi

if [ -z "$hash" ]; then
  echo "ERROR: Failed to extract hash for $platform"
  cat build.log
  exit 1
fi

echo "Hash for $platform: $hash"

# Update hashes.json
jq --arg platform "$platform" --arg hash "$hash" \
  '.node_modules[$platform] = $hash' \
  packages/opencode/hashes.json > packages/opencode/hashes.json.tmp
mv packages/opencode/hashes.json.tmp packages/opencode/hashes.json
