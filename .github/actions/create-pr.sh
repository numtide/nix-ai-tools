#!/usr/bin/env bash
set -euo pipefail

# Script to create or update a pull request for package/flake updates

# Ensure GH_TOKEN is set
if [ -z "${GH_TOKEN:-}" ]; then
  echo "Error: GH_TOKEN environment variable is not set"
  exit 1
fi
# Usage: create-update-pr.sh <type> <name> <current_version> <new_version>
#   type: "package" or "flake-input"
#   name: package name or input name
#   current_version: current version/revision
#   new_version: new version/revision

type="$1"
name="$2"
current_version="$3"
new_version="$4"

# Extract optional arguments from environment
pr_labels="${PR_LABELS:-dependencies,automated}"
auto_merge="${AUTO_MERGE:-false}"

# Handle type-specific logic
if [ "$type" = "package" ]; then
  branch="update/${name}"
  pr_title="${name}: ${current_version} -> ${new_version}"
  pr_body="Automated update of ${name} from ${current_version} to ${new_version}."
elif [ "$type" = "flake-input" ]; then
  branch="update-${name}"
  pr_title="flake.lock: Update ${name}"

  pr_body="This PR updates the flake input \`${name}\` to the latest version.

## Changes
- ${name}: \`${current_version}\` → \`${new_version}\`"
else
  echo "Error: Unknown type '$type'. Must be 'package' or 'flake-input'."
  exit 1
fi

# Stage changes first
git add .

# Create a new branch from current HEAD
# This works whether the branch exists on remote or not
git checkout -b "$branch"

if [ "$type" = "flake-input" ]; then
  commit_message="$pr_title

${current_version} -> ${new_version}"
else
  commit_message="$pr_title"
fi

git commit -m "$commit_message" --signoff

# Push the branch (force push to handle updates)
git push --force origin "$branch"

# Check if PR already exists
pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number // empty')

if [ -n "$pr_number" ]; then
  echo "Updating existing PR #$pr_number"
  gh pr edit "$pr_number" \
    --title "$pr_title" \
    --body "$pr_body"
else
  echo "Creating new PR"
  # Build label arguments array
  label_args=()
  IFS=',' read -ra labels <<<"$pr_labels"
  for label in "${labels[@]}"; do
    # Trim whitespace from label
    label=$(echo "$label" | xargs)
    label_args+=(--label "$label")
  done

  gh pr create \
    --title "$pr_title" \
    --body "$pr_body" \
    --base main \
    --head "$branch" \
    "${label_args[@]}"

  # Store PR number for auto-merge
  pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number')
fi

# Enable auto-merge if requested
if [ "$auto_merge" = "true" ] && [ -n "$pr_number" ]; then
  echo "Enabling auto-merge for PR #$pr_number"
  gh pr merge "$pr_number" --auto --squash || echo "Note: Auto-merge may require branch protection rules"
fi
