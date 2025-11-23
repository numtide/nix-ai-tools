#!/usr/bin/env bash
set -euo pipefail

# Script to generate markdown documentation for all packages using nix eval

# Discover and sort all packages
# Find directories containing package.nix or default.nix, extract basename, and sort
mapfile -t packages < <(
  find packages -maxdepth 2 -type f \( -name "package.nix" -o -name "default.nix" \) \
    -exec dirname {} \; | xargs -n1 basename | LC_ALL=C sort -u
)

# Generate markdown for each package
for package in "${packages[@]}"; do
  # Get all metadata in a single eval using the flake output
  metadata=$(nix eval --json ".#$package" --apply '
    pkg:
    let
      license = pkg.meta.license or null;
      licenseStr =
        if license == null then "Check package"
        else if builtins.isAttrs license && license ? spdxId then license.spdxId
        else if builtins.isAttrs license && license ? shortName then license.shortName
        else if builtins.isString license then license
        else "Check package";

      # Determine source type from sourceProvenance
      sourceProvenance = pkg.meta.sourceProvenance or null;
      sourceType =
        if sourceProvenance != null then
          if builtins.isList sourceProvenance then
            if builtins.any (s: s.shortName or "" == "fromSource") sourceProvenance then "source"
            else if builtins.any (s: s.shortName or "" == "binaryNativeCode") sourceProvenance then "binary"
            else if builtins.any (s: s.shortName or "" == "binaryBytecode") sourceProvenance then "bytecode"
            else "unknown"
          else "unknown"
        else "unknown";
    in {
      description = pkg.meta.description or "No description available";
      version = pkg.version or "unknown";
      license = licenseStr;
      homepage = pkg.meta.homepage or null;
      sourceType = sourceType;
      hideFromDocs = pkg.passthru.hideFromDocs or false;
    }
  ' 2>/dev/null || echo '{}')

  # Extract values from JSON
  if [ "$metadata" != "{}" ]; then
    hideFromDocs=$(echo "$metadata" | jq -r '.hideFromDocs')

    # Skip if package should be hidden from docs
    if [ "$hideFromDocs" = "true" ]; then
      continue
    fi

    description=$(echo "$metadata" | jq -r '.description')
    version=$(echo "$metadata" | jq -r '.version')
    license=$(echo "$metadata" | jq -r '.license')
    homepage=$(echo "$metadata" | jq -r '.homepage // null')
    sourceType=$(echo "$metadata" | jq -r '.sourceType')
  else
    description="No description available"
    version="unknown"
    license="Check package"
    homepage="null"
    sourceType="unknown"
  fi

  echo "#### $package"
  echo ""

  # Format the output
  echo "- **Description**: $description"
  echo "- **Version**: $version"
  echo "- **Source**: $sourceType"
  echo "- **License**: $license"
  if [ "$homepage" != "null" ]; then
    echo "- **Homepage**: $homepage"
  fi
  echo "- **Usage**: \`nix run github:numtide/nix-ai-tools#$package -- --help\`"

  # Check for package-specific README
  if [ -f "packages/$package/README.md" ]; then
    echo "- **Documentation**: See [packages/$package/README.md](packages/$package/README.md) for detailed usage"
  fi

  echo ""
done
