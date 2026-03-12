"""Shared utilities for CI update scripts."""

import logging
import os
import subprocess
from enum import StrEnum
from pathlib import Path

log = logging.getLogger(__name__)


class UpdateType(StrEnum):
    """Type of update: package or flake input."""

    PACKAGE = "package"
    FLAKE_INPUT = "flake-input"


def run(
    cmd: list[str],
    *,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run a command, optionally capturing output."""
    return subprocess.run(cmd, capture_output=capture, text=True, check=check)


def write_output(key: str, value: str) -> None:
    """Write a key=value pair to GITHUB_OUTPUT or log for local testing."""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a") as f:
            f.write(f"{key}={value}\n")
    else:
        log.info("output: %s=%s", key, value)


def nix_eval_raw(expr: str) -> str | None:
    """Evaluate a nix expression and return the raw string, or None on failure."""
    result = run(["nix", "eval", expr, "--raw"], check=False, capture=True)
    return result.stdout if result.returncode == 0 else None
