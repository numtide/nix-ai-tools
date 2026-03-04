"""Bun package utilities for Nix package updates.

Provides helpers for regenerating bun.nix lockfiles using bun2nix,
used by packages that depend on the bun2nix flake input.
"""

import subprocess
import tempfile
from pathlib import Path

from .nix import run_command

# Resolved once and cached
_BUN2NIX_BIN: str | None = None


def _resolve_bun2nix(flake_root: Path) -> str:
    """Resolve the bun2nix binary from the flake's bun2nix input.

    Uses ``nix eval --impure`` to read the locked flake input and
    obtain the store path for bun2nix, which is pinned in flake.lock.

    Args:
        flake_root: Root directory of the flake (where flake.nix lives)

    Returns:
        Path to the bun2nix binary

    """
    global _BUN2NIX_BIN  # noqa: PLW0603
    if _BUN2NIX_BIN is not None:
        return _BUN2NIX_BIN

    # Build the Nix expression to resolve bun2nix from the flake input.
    # Uses Nix interpolation (${...}) so we avoid Python f-string confusion.
    nix_expr = (
        f"let flake = builtins.getFlake (toString {flake_root}); "
        'sys = builtins.currentSystem; in "${flake.inputs.bun2nix.packages.${sys}.bun2nix}"'
    )
    result = run_command(
        [
            "nix",
            "eval",
            "--raw",
            "--impure",
            "--expr",
            nix_expr,
        ],
        cwd=flake_root,
    )
    store_path = result.stdout.strip()
    _BUN2NIX_BIN = f"{store_path}/bin/bun2nix"
    return _BUN2NIX_BIN


def regenerate_bun_nix(
    bun_lock_path: Path,
    bun_nix_output: Path,
    flake_root: Path,
) -> None:
    """Regenerate a bun.nix file from a bun.lock using bun2nix.

    Args:
        bun_lock_path: Path to the bun.lock file
        bun_nix_output: Path where bun.nix should be written
        flake_root: Root directory of the flake (to resolve bun2nix input)

    Raises:
        RuntimeError: If bun2nix fails

    """
    bun2nix_bin = _resolve_bun2nix(flake_root)

    try:
        run_command(
            [
                bun2nix_bin,
                "--lock-file",
                str(bun_lock_path),
                "--output-file",
                str(bun_nix_output),
            ],
        )
        print(f"Regenerated {bun_nix_output.name}")
    except Exception as e:
        msg = f"bun2nix failed: {e}"
        raise RuntimeError(msg) from e


def clone_and_generate_bun_nix(
    owner: str,
    repo: str,
    version: str,
    bun_nix_output: Path,
    flake_root: Path,
    *,
    ref_prefix: str = "",
) -> None:
    """Clone a repo at a given version and regenerate bun.nix from its bun.lock.

    This is the high-level helper most update.py scripts should use.
    It handles cloning the repo, locating the bun.lock, and running bun2nix.

    If the repo does not contain a bun.lock, it runs ``bun install`` to
    generate one first (requires bun on PATH).

    Args:
        owner: GitHub repository owner
        repo: GitHub repository name
        version: Version tag or commit to check out
        bun_nix_output: Path where bun.nix should be written
        flake_root: Root directory of the flake
        ref_prefix: Prefix for the git ref (e.g. "v" for "v1.0.0" tags)

    """
    ref = f"{ref_prefix}{version}"

    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = Path(tmpdir) / repo

        print(f"Cloning {owner}/{repo} at {ref}...")
        subprocess.run(
            [
                "git",
                "clone",
                "--depth=1",
                f"--branch={ref}",
                f"https://github.com/{owner}/{repo}.git",
                str(repo_dir),
            ],
            check=True,
            capture_output=True,
        )

        bun_lock = repo_dir / "bun.lock"
        if not bun_lock.exists():
            print("No bun.lock found, running bun install...")
            subprocess.run(
                ["bun", "install", "--frozen-lockfile"],
                cwd=repo_dir,
                check=False,
                capture_output=True,
            )
            # If frozen-lockfile fails, try without it
            if not bun_lock.exists():
                subprocess.run(
                    ["bun", "install"],
                    cwd=repo_dir,
                    check=True,
                    capture_output=True,
                )

        if not bun_lock.exists():
            msg = f"Could not find or generate bun.lock in {owner}/{repo}"
            raise FileNotFoundError(msg)

        regenerate_bun_nix(bun_lock, bun_nix_output, flake_root)
