#!/usr/bin/env python3
"""Fail PRs that add packages with no meta.maintainers.

We compare the package set on the PR head against the base branch and
require every attribute that exists on head but not on base to declare
at least one maintainer. Existing packages with empty maintainers are
grandfathered; this only guards new contributions.

On GitHub's ``pull_request`` event the checked-out HEAD is the synthetic
merge of the PR into the base branch, so ``head - base`` is exactly the
set of packages the PR introduces, regardless of how stale the PR branch
is. The check evaluates two flakes side by side via
``builtins.getFlake`` so it stays cheap (no builds).
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import cast

log = logging.getLogger("check-maintainers")

# Nix expression: for one flake, return { <pkg> = <maintainer-count>; }.
# Hidden helper packages (passthru.hideFromDocs) are skipped — they are
# internal infra (hooks, go-bin, etc.) and not subject to this policy.
# Inputs come in via env vars because `nix eval --expr` does not accept
# --argstr.
EXPR = r"""
let
  path = builtins.getEnv "CHECK_FLAKE_PATH";
  system = builtins.getEnv "CHECK_SYSTEM";
  flake = builtins.getFlake path;
  pkgs = flake.packages.${system} or { };
  lib = flake.inputs.nixpkgs.lib;
  isHidden = pkg: (builtins.tryEval (pkg.passthru.hideFromDocs or false)).value or false;
  count =
    name: pkg:
    let
      m = builtins.tryEval (pkg.meta.maintainers or [ ]);
    in
    if isHidden pkg then null else if m.success then builtins.length m.value else 0;
in
lib.filterAttrs (_: v: v != null) (builtins.mapAttrs count pkgs)
"""


def nix_eval_counts(flake_dir: Path, system: str) -> dict[str, int]:
    """Evaluate maintainer counts for one flake."""
    env = {
        "CHECK_FLAKE_PATH": str(flake_dir.resolve()),
        "CHECK_SYSTEM": system,
    }
    cmd = ["nix", "eval", "--impure", "--json", "--expr", EXPR]
    out = subprocess.run(
        cmd, check=True, capture_output=True, text=True, env={**os.environ, **env}
    ).stdout
    return cast("dict[str, int]", json.loads(out))


def git(*args: str, cwd: Path | None = None) -> str:
    """Run git and return stdout."""
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True, cwd=cwd
    ).stdout.strip()


def prepare_base_worktree(repo: Path, base_ref: str) -> Path:
    """Create a detached worktree at ``base_ref`` for evaluation.

    Using a worktree (rather than ``git archive`` or evaluating
    ``github:owner/repo/<sha>``) keeps the flake input cache warm and
    avoids re-downloading nixpkgs for the base revision.
    """
    base_sha = git("rev-parse", base_ref, cwd=repo)
    log.info("base ref %s -> %s", base_ref, base_sha[:12])
    tmp = Path(tempfile.mkdtemp(prefix="maint-base-"))
    git("worktree", "add", "--detach", str(tmp), base_sha, cwd=repo)
    return tmp


def main() -> int:
    """Evaluate both flakes and fail on new packages with no maintainers."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-ref",
        default="origin/main",
        help="Ref to diff against (the PR base, already fetched).",
    )
    parser.add_argument(
        "--system",
        default="x86_64-linux",
        help="Platform to evaluate packages for.",
    )
    args = parser.parse_args()

    repo = Path.cwd()
    base_dir = prepare_base_worktree(repo, args.base_ref)
    try:
        head = nix_eval_counts(repo, args.system)
        base = nix_eval_counts(base_dir, args.system)
    finally:
        git("worktree", "remove", "--force", str(base_dir), cwd=repo)

    new = sorted(set(head) - set(base))
    if not new:
        log.info("No new packages in this PR.")
        return 0

    log.info("New packages: %s", ", ".join(new))
    bad = [name for name in new if head.get(name, 0) == 0]
    if not bad:
        log.info("All new packages declare at least one maintainer.")
        return 0

    for name in bad:
        print(
            f"::error file=packages/{name}/package.nix"
            f"::New package '{name}' has empty meta.maintainers. "
            "Add yourself (see lib/default.nix for the local maintainer list)."
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
