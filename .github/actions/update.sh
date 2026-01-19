#!/usr/bin/env bash
set -euo pipefail

# Script to perform updates for packages or flake inputs
# Usage: update.sh <type> <name>
#   type: "package" or "flake-input"
#   name: package name or input name

type="$1"
name="$2"

export NIX_PATH=nixpkgs=flake:nixpkgs

# Outputs are written to GITHUB_OUTPUT if available
output_var="${GITHUB_OUTPUT:-/dev/stdout}"

if [ "$type" = "package" ]; then
  echo "Updating package $name..."

  # Load nix-update args early (used for initial update and potential retries)
  nix_update_args=()
  if [ -f "packages/$name/nix-update-args" ]; then
    echo "Loading nix-update args from packages/$name/nix-update-args"
    mapfile -t nix_update_args <"packages/$name/nix-update-args"
  fi

  # Check if package has an update script
  if [ -f "packages/$name/update.py" ]; then
    echo "Running update script for $name..."
    if output=$(packages/"$name"/update.py 2>&1); then
      echo "$output"
    else
      echo "::error::Update script failed for package $name"
      echo "$output"
      exit 1
    fi
  else
    # Try nix-update
    echo "No update script found, trying nix-update..."
    if output=$(nix-update --flake "$name" "${nix_update_args[@]}" 2>&1); then
      echo "$output"
    else
      echo "::error::nix-update failed for package $name"
      echo "$output"
      exit 1
    fi
  fi

  # Check if there were actual changes
  if git diff --quiet; then
    echo "No changes detected"
    echo "updated=false" >>"$output_var"
    exit 0
  fi

  # Get the new version
  new_version=$(nix eval .#packages.x86_64-linux."$name".version --raw 2>/dev/null || echo "unknown")
  echo "New version: $new_version"

  # Verify the package actually builds with the new hashes
  # This catches npm registry non-determinism issues where hashes become stale
  echo "Verifying package builds..."
  if ! nix build .#"$name" --no-link 2>&1; then
    echo "::error::Package $name failed to build after update"
    echo "This may be due to npm registry non-determinism. Retrying hash computation..."

    # Retry nix-update to recompute hashes
    if output=$(nix-update --flake "$name" "${nix_update_args[@]}" 2>&1); then
      echo "$output"
      # Try building again
      if ! nix build .#"$name" --no-link 2>&1; then
        echo "::error::Package $name still fails to build after retry"
        exit 1
      fi
    else
      echo "::error::nix-update retry failed for package $name"
      echo "$output"
      exit 1
    fi
  fi
  echo "Build verification passed"

  echo "updated=true" >>"$output_var"
  echo "new_version=$new_version" >>"$output_var"

elif [ "$type" = "flake-input" ]; then
  echo "Updating input $name..."

  if nix flake update "$name"; then
    # Check if there were actual changes
    if git diff --quiet; then
      echo "No changes detected"
      echo "updated=false" >>"$output_var"
      exit 0
    fi

    # Get new revision
    new_rev=$(nix flake metadata --json --no-write-lock-file | jq -r ".locks.nodes.\"$name\".locked.rev // \"unknown\"" | head -c 8)
    echo "New revision: $new_rev"

    echo "updated=true" >>"$output_var"
    echo "new_version=$new_rev" >>"$output_var"
  else
    echo "::error::Failed to update $name"
    exit 1
  fi
else
  echo "Error: Unknown type '$type'. Must be 'package' or 'flake-input'."
  exit 1
fi
