{ pkgs }:
pkgs.writeShellApplication {
  name = "update-packages";
  runtimeInputs = with pkgs; [
    nix-update
    git
    jq
    curl
    nodejs_20  # Includes npm, needed for some package update scripts
  ];
  text = ''
    set -euo pipefail

    # Get the flake directory
    flake_dir="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    cd "$flake_dir"

    # Check for --list-only flag first
    if [ "$#" -eq 1 ] && [ "$1" = "--list-only" ]; then
        # Output packages with package.nix as JSON array
        packages_array=()
        for package_file in packages/*/package.nix; do
            if [ -f "$package_file" ]; then
                pkg=$(basename "$(dirname "$package_file")")
                packages_array+=("\"$pkg\"")
            fi
        done
        # Convert to JSON array format
        echo "[$(IFS=,; echo "''${packages_array[*]}")]"
        exit 0
    fi

    # Check if specific packages were provided
    if [ $# -gt 0 ]; then
        # Use provided packages, but filter for those with package.nix
        packages=()
        for pkg in "$@"; do
            if [ -f "packages/$pkg/package.nix" ]; then
                packages+=("$pkg")
            else
                echo "Warning: Skipping $pkg (no package.nix file)"
            fi
        done
        if [ ''${#packages[@]} -eq 0 ]; then
            echo "No valid packages to update"
            exit 0
        fi
        echo "Updating specified packages: ''${packages[*]}"
    else
        # Get all packages with package.nix files
        echo "Updating all packages in the flake..."
        packages=()
        for package_file in packages/*/package.nix; do
            if [ -f "$package_file" ]; then
                pkg=$(basename "$(dirname "$package_file")")
                packages+=("$pkg")
            fi
        done
    fi
    echo

    # Track results
    updated=()
    failed=()
    already_uptodate=()

    for pkg in "''${packages[@]}"; do

        # Get current version
        current_version=$(nix eval --raw .#packages.x86_64-linux."$pkg".version 2>/dev/null || echo "unknown")
        echo "Checking $pkg (current: $current_version)..."

        # Check if package has a custom update script
        # Look for the update script in the source tree
        update_script_path="packages/$pkg/update.sh"
        if [ -f "$update_script_path" ] && [ -x "$update_script_path" ]; then
            echo "  Using custom update script..."
            # Capture output to extract version info
            if output=$("$update_script_path" 2>&1); then
                # Try to extract version info from output
                if echo "$output" | grep -q "Update available:"; then
                    new_version=$(echo "$output" | grep "Update available:" | sed -E 's/.*-> ([0-9.]+).*/\1/')
                    updated+=("$pkg: $current_version → $new_version")
                    echo "  ✓ Updated successfully ($current_version → $new_version)"
                elif echo "$output" | grep -q "already up to date"; then
                    already_uptodate+=("$pkg: $current_version")
                    echo "  ✓ Already up to date at $current_version"
                else
                    # Package was updated but version extraction failed
                    new_version=$(nix eval --raw .#packages.x86_64-linux."$pkg".version 2>/dev/null || echo "unknown")
                    if [ "$new_version" != "$current_version" ]; then
                        updated+=("$pkg: $current_version → $new_version")
                        echo "  ✓ Updated successfully ($current_version → $new_version)"
                    else
                        updated+=("$pkg: version unknown")
                        echo "  ✓ Updated successfully"
                    fi
                fi
            else
                failed+=("$pkg: $current_version")
                echo "  ✗ Failed to update (current: $current_version)"
            fi
        else
            # Use nix-update for packages without custom scripts
            if output=$(nix-update --flake --version=stable "$pkg" 2>&1); then
                if echo "$output" | grep -q "Package already up to date"; then
                    already_uptodate+=("$pkg: $current_version")
                    echo "  ✓ Already up to date at $current_version"
                else
                    # Get new version after update
                    new_version=$(nix eval --raw .#packages.x86_64-linux."$pkg".version 2>/dev/null || echo "unknown")
                    updated+=("$pkg: $current_version → $new_version")
                    echo "  ✓ Updated successfully ($current_version → $new_version)"
                fi
            else
                failed+=("$pkg: $current_version")
                echo "  ✗ Failed to update (current: $current_version)"
            fi
        fi
        echo
    done

    # Summary
    echo "Update Summary:"
    echo "==============="

    if [ ''${#updated[@]} -gt 0 ]; then
        echo "Updated (''${#updated[@]}):"
        printf "  - %s\n" "''${updated[@]}"
    fi

    if [ ''${#already_uptodate[@]} -gt 0 ]; then
        echo "Already up to date (''${#already_uptodate[@]}):"
        printf "  - %s\n" "''${already_uptodate[@]}"
    fi

    if [ ''${#failed[@]} -gt 0 ]; then
        echo "Failed (''${#failed[@]}):"
        printf "  - %s\n" "''${failed[@]}"
        echo
        echo "Note: Some packages may need manual intervention or custom update scripts."
    fi

    if [ ''${#updated[@]} -gt 0 ]; then
        echo
        echo "Don't forget to:"
        echo "  1. Review the changes: git diff"
        echo "  2. Build updated packages: nix build .#packages.x86_64-linux.<package>"
        echo "  3. Commit the updates"
    fi

    # Exit with error code if there were any failures
    if [ ''${#failed[@]} -gt 0 ]; then
        exit 1
    fi
  '';
}
