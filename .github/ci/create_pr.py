#!/usr/bin/env python3
"""Create or update a pull request for package/flake updates.

Environment variables:
  GH_TOKEN: GitHub token (required)
  PR_LABELS: Comma-separated list of labels (default: "dependencies,automated")
  AUTO_MERGE: Enable auto-merge (default: "false")
  CHANGELOG_URL: Changelog URL to include in commit body (optional)
"""

import argparse
import logging
import os
import sys
from dataclasses import dataclass

from lib import UpdateType, run

log = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PrConfig:
    """All the data needed to create a PR."""

    branch: str
    title: str
    body: str
    commit_message: str


def gh_get_pr_number(branch: str) -> str | None:
    """Get the PR number for a branch, or None if no PR exists."""
    result = run(
        [
            "gh",
            "pr",
            "list",
            "--head",
            branch,
            "--json",
            "number",
            "--jq",
            ".[0].number // empty",
        ],
        capture=True,
    )
    return result.stdout.strip() or None


def build_config(
    *,
    update_type: UpdateType,
    name: str,
    current_version: str,
    new_version: str,
    changelog_url: str,
) -> PrConfig:
    """Build branch, title, body, and commit message from update parameters."""
    match update_type:
        case UpdateType.PACKAGE:
            branch = f"update/{name}"
            title = f"{name}: {current_version} -> {new_version}"
            body = (
                f"Automated update of {name} from {current_version} to {new_version}."
            )
            commit_message = f"{title}\n\n{changelog_url}" if changelog_url else title

        case UpdateType.FLAKE_INPUT:
            branch = f"update-{name}"
            title = f"flake.lock: Update {name}"
            body = (
                f"This PR updates the flake input `{name}` to the latest version.\n\n"
                f"## Changes\n"
                f"- {name}: `{current_version}` → `{new_version}`"
            )
            commit_message = f"{title}\n\n{current_version} -> {new_version}"

    return PrConfig(
        branch=branch, title=title, body=body, commit_message=commit_message
    )


def create_or_update_pr(config: PrConfig, *, labels: str, auto_merge: bool) -> None:
    """Stage, commit, push, and create/update the PR."""
    run(["git", "add", "."])
    run(["git", "checkout", "-b", config.branch])
    run(["git", "commit", "-m", config.commit_message, "--signoff"])
    run(["git", "push", "--force", "origin", config.branch])

    pr_number = gh_get_pr_number(config.branch)

    if pr_number:
        log.info("Updating existing PR #%s", pr_number)
        run(
            [
                "gh",
                "pr",
                "edit",
                pr_number,
                "--title",
                config.title,
                "--body",
                config.body,
            ]
        )
    else:
        log.info("Creating new PR")
        label_args: list[str] = [
            arg
            for raw in labels.split(",")
            if (stripped := raw.strip())
            for arg in ("--label", stripped)
        ]
        run(
            [
                "gh",
                "pr",
                "create",
                "--title",
                config.title,
                "--body",
                config.body,
                "--base",
                "main",
                "--head",
                config.branch,
                *label_args,
            ]
        )
        pr_number = gh_get_pr_number(config.branch)

    if auto_merge and pr_number:
        log.info("Enabling auto-merge for PR #%s", pr_number)
        run(["gh", "pr", "merge", pr_number, "--auto", "--squash"], check=False)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "type", choices=[t.value for t in UpdateType], help="update type"
    )
    parser.add_argument("name", help="package or flake input name")
    parser.add_argument("current_version", help="current version or revision")
    parser.add_argument("new_version", help="new version or revision")
    return parser.parse_args()


def main() -> None:
    """Create or update a PR for a package or flake-input update."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    if not os.environ.get("GH_TOKEN"):
        log.error("GH_TOKEN environment variable is not set")
        sys.exit(1)

    args = parse_args()
    config = build_config(
        update_type=UpdateType(args.type),
        name=args.name,
        current_version=args.current_version,
        new_version=args.new_version,
        changelog_url=os.environ.get("CHANGELOG_URL", ""),
    )
    create_or_update_pr(
        config,
        labels=os.environ.get("PR_LABELS", "dependencies,automated"),
        auto_merge=os.environ.get("AUTO_MERGE", "false") == "true",
    )


if __name__ == "__main__":
    main()
