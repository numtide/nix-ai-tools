#!/usr/bin/env bash
set -euo pipefail

# Script to test the discovery phase locally
# This mimics what happens in the GitHub Actions workflow

# Set defaults (can be overridden with environment variables)
PACKAGES="${PACKAGES:-}"
INPUTS="${INPUTS:-}"

echo "=== Discovery Configuration ==="
echo "PACKAGES: ${PACKAGES:-<all>}"
echo "INPUTS: ${INPUTS:-<all>}"
echo

# Initialize arrays for different update types
declare -a matrix_items=()

# Discover packages
echo "Discovering packages..."

if [ -n "$PACKAGES" ]; then
  # Specific packages provided
  packages="$PACKAGES"
  for package in $packages; do
    version=$(nix eval .#packages.x86_64-linux."$package".version --raw 2>/dev/null || echo "unknown")
    if [ "$version" != "unknown" ]; then
      matrix_items+=("{\"type\":\"package\",\"name\":\"$package\",\"current_version\":\"$version\"}")
    else
      echo "Warning: Package $package has no version, skipping"
    fi
  done
else
  # Get all packages by traversing the flake
  # Get the system attribute (use x86_64-linux as default)
  system="${SYSTEM:-x86_64-linux}"

  # List all packages for the system
  if packages_json=$(nix eval .#packages."$system" --json 2>/dev/null); then
    # Get all package names
    package_names=$(echo "$packages_json" | jq -r 'keys[]' | sort)

    for package in $package_names; do
      # Try to get the version
      version=$(nix eval .#packages."$system"."$package".version --raw 2>/dev/null || echo "")
      if [ -n "$version" ]; then
        matrix_items+=("{\"type\":\"package\",\"name\":\"$package\",\"current_version\":\"$version\"}")
      else
        echo "Skipping $package (no version attribute)"
      fi
    done
  else
    echo "Failed to list packages"
  fi
fi

# Discover flake inputs
echo "Discovering flake inputs..."

# Check if flake.lock exists
if [ ! -f "flake.lock" ]; then
  echo "No flake.lock found, skipping input updates"
else
  # Get flake metadata
  if metadata=$(nix flake metadata --json --no-write-lock-file 2>/dev/null); then
    if [ -n "$INPUTS" ]; then
      # Specific inputs requested
      requested_inputs="$INPUTS"
      for input in $requested_inputs; do
        # Check if this input exists in the flake
        if echo "$metadata" | jq -e ".locks.nodes.\"$input\"" >/dev/null 2>&1; then
          current_rev=$(echo "$metadata" | jq -r ".locks.nodes.\"$input\".locked.rev // \"unknown\"" | head -c 8)
          matrix_items+=("{\"type\":\"flake-input\",\"name\":\"$input\",\"current_version\":\"$current_rev\"}")
        fi
      done
    else
      # Get all inputs
      inputs=$(echo "$metadata" | jq -r '.locks.nodes | to_entries[] | select(.key != "root") | .key' | sort)

      for input in $inputs; do
        current_rev=$(echo "$metadata" | jq -r ".locks.nodes.\"$input\".locked.rev // \"unknown\"" | head -c 8)
        matrix_items+=("{\"type\":\"flake-input\",\"name\":\"$input\",\"current_version\":\"$current_rev\"}")
      done
    fi
  fi
fi

echo
echo "=== Discovery Results ==="

# Create matrix JSON
if [ ${#matrix_items[@]} -eq 0 ]; then
  matrix='{"include":[]}'
  has_updates="false"
  echo "No items to update"
else
  matrix_json='{"include":['
  for i in "${!matrix_items[@]}"; do
    if [ "$i" -gt 0 ]; then
      matrix_json+=","
    fi
    matrix_json+="${matrix_items[$i]}"
  done
  matrix_json+="]}"

  matrix="$matrix_json"
  has_updates="true"
  echo "Found ${#matrix_items[@]} item(s) to update"
fi

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "matrix=$matrix" >>"$GITHUB_OUTPUT"
  echo "has-updates=$has_updates" >>"$GITHUB_OUTPUT"
else
  # Local testing output
  echo
  echo "=== GitHub Actions Output Format ==="
  echo "matrix=$matrix"
  echo "has-updates=$has_updates"

  echo
  echo "=== Pretty-printed Matrix ==="
  echo "$matrix" | jq .

  echo
  echo "=== Summary ==="
  if [ "$has_updates" = "true" ]; then
    echo "Items by type:"
    echo "$matrix" | jq -r '.include[] | .type' | sort | uniq -c
  fi
fi
