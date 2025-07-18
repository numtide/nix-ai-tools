{ pkgs }:
pkgs.writeShellApplication {
  name = "update-packages";
  runtimeInputs = with pkgs; [
    nix-update
    git
    jq
    curl
  ];
  text = ''
    set -euo pipefail

    # Get the flake directory
    flake_dir="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    cd "$flake_dir"

    # Check for --list-only flag first
    if [ "$#" -eq 1 ] && [ "$1" = "--list-only" ]; then
        # Just list packages that would be updated
        nix eval --json --impure .#packages.x86_64-linux --apply 'builtins.attrNames' | jq -r '.[]' | grep -v -E '^(update-packages|default|formatter)$'
        exit 0
    fi

    # Check if specific packages were provided
    if [ $# -gt 0 ]; then
        # Use provided packages
        packages=("$@")
        echo "Updating specified packages: ''${packages[*]}"
    else
        # Get all packages from the flake
        echo "Updating all packages in the flake..."
        mapfile -t packages < <(nix eval --json --impure .#packages.x86_64-linux --apply 'builtins.attrNames' | jq -r '.[]')
    fi
    echo

    # Track results
    updated=()
    failed=()
    already_uptodate=()

    for pkg in "''${packages[@]}"; do
        echo "Checking $pkg..."
        
        # Skip packages that are not meant to be updated
        case "$pkg" in
            update-packages|default|formatter)
                echo "  Skipping $pkg"
                continue
                ;;
        esac

        # Use nix-update with -u to use passthru.updateScript if available
        if output=$(nix-update --flake --use-update-script --version=stable "$pkg" 2>&1); then
            if echo "$output" | grep -q "Package already up to date"; then
                already_uptodate+=("$pkg")
                echo "  ✓ Already up to date"
            else
                updated+=("$pkg")
                echo "  ✓ Updated successfully"
            fi
        else
            failed+=("$pkg")
            echo "  ✗ Failed to update"
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
  '';
}
