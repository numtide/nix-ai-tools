"""Bun package utilities for Nix package updates.

Provides helpers for regenerating bun.nix lockfiles using bun2nix,
used by packages that depend on the bun2nix flake input.
"""

import subprocess
import tempfile
from pathlib import Path

from .nix import run_command


def regenerate_bun_nix(
    bun_lock_path: Path,
    bun_nix_output: Path,
    flake_root: Path,
) -> None:
    """Regenerate a bun.nix file from a bun.lock using bun2nix.

    Runs bun2nix directly from the flake's bun2nix input via
    ``nix run --inputs-from``, which handles building and caching
    the binary automatically.

    Args:
        bun_lock_path: Path to the bun.lock file
        bun_nix_output: Path where bun.nix should be written
        flake_root: Root directory of the flake (to resolve bun2nix input)

    Raises:
        RuntimeError: If bun2nix fails

    """
    try:
        run_command(
            [
                "nix",
                "run",
                "--inputs-from",
                str(flake_root),
                "bun2nix#bun2nix",
                "--",
                "--lock-file",
                str(bun_lock_path),
                "--output-file",
                str(bun_nix_output),
            ],
            cwd=flake_root,
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
