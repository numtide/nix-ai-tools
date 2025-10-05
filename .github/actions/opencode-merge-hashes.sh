#!/usr/bin/env bash
set -euo pipefail

# Start with the base hashes.json from the package update
cp packages/opencode/hashes.json /tmp/merged-hashes.json

# Merge all platform-specific hash updates
for hash_file in /tmp/hashes/hash-*/hashes.json; do
  echo "Merging hashes from $hash_file"
  jq -s '.[0] * .[1]' /tmp/merged-hashes.json "$hash_file" > /tmp/merged-hashes.json.tmp
  mv /tmp/merged-hashes.json.tmp /tmp/merged-hashes.json
done

# Validate all platforms have hashes
for platform in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
  hash=$(jq -r ".node_modules[\"$platform\"]" /tmp/merged-hashes.json)
  if [ -z "$hash" ] || [ "$hash" = "null" ]; then
    echo "ERROR: Missing hash for platform $platform"
    exit 1
  fi
  echo "✓ $platform: $hash"
done

# Copy the merged hashes back
cp /tmp/merged-hashes.json packages/opencode/hashes.json
