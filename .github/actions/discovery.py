#!/usr/bin/env python3
"""Discover packages and flake inputs for update checking.

This script mimics what happens in the GitHub Actions workflow.
It discovers all packages with version attributes and all flake inputs,
outputting a matrix JSON suitable for GitHub Actions.
"""

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class MatrixItem:
    """Represents an item in the update matrix."""

    type: str
    name: str
    current_version: str

    def to_dict(self) -> dict[str, str]:
        """Convert to dictionary for JSON serialization."""
        return {
            "type": self.type,
            "name": self.name,
            "current_version": self.current_version,
        }


def run_nix(args: list[str]) -> subprocess.CompletedProcess[str]:
    """Run a nix command and return the result."""
    return subprocess.run(
        ["nix", *args],
        capture_output=True,
        text=True,
        check=False,
    )


def discover_packages(packages_filter: str | None, system: str) -> list[MatrixItem]:
    """Discover packages with version attributes in a single nix eval."""
    items: list[MatrixItem] = []

    print("Discovering packages...")

    # Build a nix expression that evaluates all versions at once
    # Pass data via env var + builtins.fromJSON to avoid string interpolation
    config = json.dumps(
        {
            "system": system,
            "filter": packages_filter.split() if packages_filter else None,
        }
    )
    expr = """
    let
      config = builtins.fromJSON (builtins.getEnv "DISCOVERY_CONFIG");
      flake = builtins.getFlake (toString ./.);
      pkgs = flake.packages.${config.system};
      getVersion = name:
        if pkgs ? ${name} && pkgs.${name} ? version
        then { inherit name; value = pkgs.${name}.version; }
        else null;
    in
      if config.filter == null then
        builtins.mapAttrs (name: pkg:
          if pkg ? version then pkg.version else null
        ) pkgs
      else
        builtins.listToAttrs
          (builtins.filter (x: x != null) (map getVersion config.filter))
    """
    env = {**os.environ, "DISCOVERY_CONFIG": config}
    result = subprocess.run(
        ["nix", "eval", "--json", "--impure", "--expr", expr],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )

    if result.returncode != 0:
        print(f"Failed to evaluate packages: {result.stderr}")
        return items

    versions = json.loads(result.stdout)

    for name in sorted(versions.keys()):
        version = versions[name]
        if version is not None:
            items.append(MatrixItem(type="package", name=name, current_version=version))
        elif not packages_filter:
            print(f"Skipping {name} (no version attribute)")

    if packages_filter:
        # Warn about missing packages
        found = set(versions.keys())
        for pkg in packages_filter.split():
            if pkg not in found:
                print(f"Warning: Package {pkg} not found or has no version")

    return items


def discover_flake_inputs(inputs_filter: str | None) -> list[MatrixItem]:
    """Discover flake inputs from flake.lock."""
    items: list[MatrixItem] = []

    print("Discovering flake inputs...")

    lock_path = Path("flake.lock")
    if not lock_path.exists():
        print("No flake.lock found, skipping input updates")
        return items

    # Read flake.lock directly - no need for nix command
    lock_data = json.loads(lock_path.read_text())
    nodes = lock_data.get("nodes", {})

    if inputs_filter:
        input_names = inputs_filter.split()
    else:
        input_names = sorted(k for k in nodes if k != "root")

    for input_name in input_names:
        if input_name not in nodes:
            continue
        locked = nodes[input_name].get("locked", {})
        rev = locked.get("rev", "unknown")[:8]
        items.append(
            MatrixItem(
                type="flake-input",
                name=input_name,
                current_version=rev,
            )
        )

    return items


def main() -> None:
    """Discover packages and flake inputs, output matrix for GitHub Actions."""
    # Get configuration from environment
    packages = os.environ.get("PACKAGES", "")
    inputs = os.environ.get("INPUTS", "")
    system = os.environ.get("SYSTEM", "x86_64-linux")
    github_output = os.environ.get("GITHUB_OUTPUT")

    print("=== Discovery Configuration ===")
    print(f"PACKAGES: {packages or '<all>'}")
    print(f"INPUTS: {inputs or '<all>'}")
    print()

    # Discover items
    matrix_items: list[MatrixItem] = []
    matrix_items.extend(discover_packages(packages or None, system))
    matrix_items.extend(discover_flake_inputs(inputs or None))

    print()
    print("=== Discovery Results ===")

    # Create matrix JSON
    matrix: dict[str, list[dict[str, str]]]
    if not matrix_items:
        matrix = {"include": []}
        has_updates = False
        print("No items to update")
    else:
        matrix = {"include": [item.to_dict() for item in matrix_items]}
        has_updates = True
        print(f"Found {len(matrix_items)} item(s) to update")

    matrix_json = json.dumps(matrix, separators=(",", ":"))

    # Output for GitHub Actions
    if github_output:
        with Path(github_output).open("a") as f:
            f.write(f"matrix={matrix_json}\n")
            f.write(f"has-updates={str(has_updates).lower()}\n")
    else:
        # Local testing output
        print()
        print("=== GitHub Actions Output Format ===")
        print(f"matrix={matrix_json}")
        print(f"has-updates={str(has_updates).lower()}")

        print()
        print("=== Pretty-printed Matrix ===")
        print(json.dumps(matrix, indent=2))

        print()
        print("=== Summary ===")
        if has_updates:
            print("Items by type:")
            type_counts: dict[str, int] = {}
            for item in matrix_items:
                type_counts[item.type] = type_counts.get(item.type, 0) + 1
            for item_type, count in sorted(type_counts.items()):
                print(f"  {count} {item_type}")


if __name__ == "__main__":
    main()
