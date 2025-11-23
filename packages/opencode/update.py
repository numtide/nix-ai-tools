#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 nix
"""Update the opencode package version and hashes."""

import re
import subprocess
import sys
from pathlib import Path

def run_command(cmd: list[str], check: bool = True) -> tuple[int, str, str]:
    """Run a command and return (returncode, stdout, stderr)."""
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=False,
    )
    if check and result.returncode != 0:
        print(f"Command failed: {' '.join(cmd)}", file=sys.stderr)
        print(f"stderr: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.returncode, result.stdout, result.stderr

def main() -> None:
    # Get script directory and package file path
    script_dir = Path(__file__).parent.resolve()
    package_file = script_dir / "package.nix"

    print("Updating opencode package...")

    # Step 1: Update the main package version and source hash
    print("Updating opencode version and source hash...")
    run_command(["nix", "run", "nixpkgs#nix-update", "--", "--flake", "opencode"], check=True)

    # Check if there were changes
    returncode, _, _ = run_command(["git", "diff", "--quiet", str(package_file)], check=False)

    if returncode != 0:  # There were changes
        print("Package version and source hash updated")

        # Step 2: Update node_modules hash
        print("Updating node_modules hash...")

        # Get old hash
        _, old_node_hash, _ = run_command(
            ["nix", "eval", ".#opencode.node_modules.outputHash"],
            check=True
        )
        old_node_hash = old_node_hash.strip().strip('"')

        if not old_node_hash:
            print("ERROR: Could not find node_modules outputHash", file=sys.stderr)
            sys.exit(1)

        print(f"Old node_modules hash: {old_node_hash}")

        # Read package file
        content = package_file.read_text()

        # Replace with dummy hash to trigger rebuild
        modified_content = content.replace(
            f'outputHash = "{old_node_hash}";',
            'outputHash = "";'
        )
        package_file.write_text(modified_content)

        # Try to build and capture the correct hash
        print("Building to get correct node_modules hash...")
        returncode, stdout, stderr = run_command(
            ["nix", "build", ".#opencode"],
            check=False
        )

        if returncode == 0:
            print("Build succeeded unexpectedly with dummy hash!")
            # Restore original hash as a fallback
            content = package_file.read_text()
            modified_content = content.replace(
                'outputHash = "";',
                f'outputHash = "{old_node_hash}";'
            )
            package_file.write_text(modified_content)
        else:
            # Extract the correct hash from error output
            combined_output = stdout + stderr
            match = re.search(r'got:\s+(sha256-[^\s]+)', combined_output)

            if match:
                new_node_hash = match.group(1)
                print(f"New node_modules hash: {new_node_hash}")

                # Update with new hash
                content = package_file.read_text()
                modified_content = content.replace(
                    'outputHash = "";',
                    f'outputHash = "{new_node_hash}";'
                )
                package_file.write_text(modified_content)
            else:
                print("ERROR: Could not extract node_modules hash from build output", file=sys.stderr)
                print("Build output:", file=sys.stderr)
                print(combined_output[-2000:], file=sys.stderr)  # Last ~2000 chars

                # Restore original hash
                content = package_file.read_text()
                modified_content = content.replace(
                    'outputHash = "";',
                    f'outputHash = "{old_node_hash}";'
                )
                package_file.write_text(modified_content)
                sys.exit(1)

        print("Update completed successfully!")
    else:
        print("No changes detected, package is already up to date")

if __name__ == "__main__":
    main()
