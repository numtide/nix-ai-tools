#!/usr/bin/env python3
"""Generate markdown documentation for all packages using nix eval."""

import json
import subprocess
import sys
from pathlib import Path


def get_all_packages_metadata() -> dict[str, dict[str, str | bool | None]]:
    """Get metadata for all packages using a single nix eval."""
    nix_file = Path(__file__).parent / "generate-package-docs.nix"

    try:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--json",
                "--file",
                str(nix_file),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error running nix eval: {e}", file=sys.stderr)
        if e.stderr:
            print(f"stderr: {e.stderr}", file=sys.stderr)
        raise

    data = json.loads(result.stdout)
    # Filter out null values (packages that failed to evaluate)
    return {k: v for k, v in data.items() if v is not None}


def generate_package_doc(package: str, metadata: dict[str, str | bool | None]) -> None:
    """Generate markdown documentation for a package."""
    description = metadata.get("description", "No description available")
    print("<details>")
    print(f"<summary><strong>{package}</strong> - {description}</summary>")
    print()
    print(f"- **Source**: {metadata.get('sourceType', 'unknown')}")
    print(f"- **License**: {metadata.get('license', 'Check package')}")

    homepage = metadata.get("homepage")
    if homepage:
        print(f"- **Homepage**: {homepage}")

    print(f"- **Usage**: `nix run github:numtide/nix-ai-tools#{package} -- --help`")
    print(
        f"- **Nix**: [packages/{package}/package.nix](packages/{package}/package.nix)"
    )

    # Check for package-specific README
    readme_path = Path(f"packages/{package}/README.md")
    if readme_path.exists():
        print(
            f"- **Documentation**: See [packages/{package}/README.md]"
            f"(packages/{package}/README.md) for detailed usage"
        )

    print()
    print("</details>")


def main() -> None:
    """Run the main documentation generation process."""
    # Get metadata for all packages at once
    all_metadata = get_all_packages_metadata()

    # Generate documentation for each package (sorted by name)
    for package in sorted(all_metadata.keys()):
        metadata = all_metadata[package]
        generate_package_doc(package, metadata)


if __name__ == "__main__":
    main()
