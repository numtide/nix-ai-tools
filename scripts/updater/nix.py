"""Nix command wrappers for package updates."""

import json
import subprocess
from pathlib import Path
from typing import cast


class NixCommandError(Exception):
    """Raised when a Nix command fails."""


def run_command(
    cmd: list[str],
    *,
    check: bool = True,
    capture_output: bool = True,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    """Run a command and return the result.

    Args:
        cmd: Command and arguments to run
        check: Whether to raise exception on non-zero exit
        capture_output: Whether to capture stdout/stderr
        cwd: Working directory for the command

    Returns:
        CompletedProcess with command results

    Raises:
        NixCommandError: If command fails and check=True

    """
    try:
        return subprocess.run(
            cmd,
            check=check,
            capture_output=capture_output,
            text=True,
            cwd=cwd,
        )
    except subprocess.CalledProcessError as e:
        msg = (
            f"Command failed: {' '.join(cmd)}\n"
            f"Exit code: {e.returncode}\n"
            f"Stdout: {e.stdout}\n"
            f"Stderr: {e.stderr}"
        )
        raise NixCommandError(
            msg,
        ) from e


def nix_command(
    args: list[str],
    *,
    check: bool = True,
    capture_output: bool = True,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    """Run a nix command with experimental features enabled.

    Args:
        args: Arguments to nix command (e.g., ["eval", ".#foo", "--raw"])
        check: Whether to raise exception on non-zero exit
        capture_output: Whether to capture stdout/stderr
        cwd: Working directory for the command

    Returns:
        CompletedProcess with command results

    """
    cmd = ["nix", "--experimental-features", "nix-command flakes", *args]
    return run_command(cmd, check=check, capture_output=capture_output, cwd=cwd)


def nix_eval(
    attr: str,
    *,
    raw: bool = True,
    json_output: bool = False,
) -> str:
    """Evaluate a Nix attribute.

    Args:
        attr: Flake attribute to evaluate (e.g., ".#package.version")
        raw: Whether to output raw value (no quotes, ignored if json_output=True)
        json_output: Whether to output as JSON (takes precedence over raw)

    Returns:
        Evaluation result as string

    """
    args = ["eval", attr]
    if json_output:
        args.append("--json")
    elif raw:
        args.append("--raw")

    result = nix_command(args)
    return result.stdout.strip()


def nix_build(
    attr: str,
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Build a Nix package.

    Args:
        attr: Flake attribute to build (e.g., ".#package")
        check: Whether to raise exception on build failure

    Returns:
        CompletedProcess with build results

    """
    args = ["build", "--log-format", "bar-with-logs", attr]
    return nix_command(args, check=check)


def nix_store_prefetch_file(url: str, hash_type: str = "sha256") -> str:
    """Prefetch a file using nix store and return its hash.

    Args:
        url: URL to prefetch
        hash_type: Hash algorithm to use

    Returns:
        Hash in SRI format

    """
    args = [
        "store",
        "prefetch-file",
        "--hash-type",
        hash_type,
        "--json",
        url,
    ]
    result = nix_command(args)
    data = json.loads(result.stdout)
    return cast("str", data["hash"])


def nix_prefetch_url(url: str, *, unpack: bool = False) -> str:
    """Prefetch a URL using nix-prefetch-url and return its hash.

    This is useful for fetchzip which needs the hash of unpacked contents.

    Args:
        url: URL to prefetch
        unpack: Whether to unpack the archive (for fetchzip)

    Returns:
        Hash in SRI format (sha256-...)

    """
    args = ["nix-prefetch-url", "--type", "sha256"]
    if unpack:
        args.append("--unpack")
    args.append(url)

    result = run_command(args)
    # nix-prefetch-url returns base32-encoded hash, convert to SRI
    hash_b32 = result.stdout.strip()

    # Convert to SRI format by using nix hash convert
    convert_args = ["hash", "convert", "--hash-algo", "sha256", hash_b32]
    convert_result = nix_command(convert_args)
    return convert_result.stdout.strip()
