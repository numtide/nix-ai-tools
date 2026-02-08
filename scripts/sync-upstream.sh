#!/usr/bin/env bash

set -euo pipefail

UPSTREAM_REMOTE_NAME="${UPSTREAM_REMOTE_NAME:-upstream}"
UPSTREAM_REMOTE_URL="${UPSTREAM_REMOTE_URL:-https://github.com/numtide/nix-ai-tools.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
BASE_REMOTE_NAME="${BASE_REMOTE_NAME:-origin}"
BASE_BRANCH="${BASE_BRANCH:-main}"
SYNC_BRANCH="${SYNC_BRANCH:-upstream-sync}"
IGNORE_FILE="${IGNORE_FILE:-.github/upstream-sync-ignore.txt}"
FORCE_SYNC="${FORCE_SYNC:-false}"
DRY_RUN="${DRY_RUN:-false}"

output_file="${GITHUB_OUTPUT:-}"

emit_output() {
  local key="$1"
  local value="$2"

  if [[ -n "$output_file" ]]; then
    printf "%s=%s\n" "$key" "$value" >>"$output_file"
  fi
  printf "%s=%s\n" "$key" "$value"
}

set_remote() {
  local name="$1"
  local url="$2"

  if git remote get-url "$name" >/dev/null 2>&1; then
    git remote set-url "$name" "$url"
  else
    git remote add "$name" "$url"
  fi
}

restore_ignored_paths() {
  if [[ ! -f "$IGNORE_FILE" ]]; then
    return
  fi

  while IFS= read -r path; do
    if [[ -z "$path" || "$path" == \#* ]]; then
      continue
    fi

    git restore --source=HEAD --staged --worktree -- "$path" 2>/dev/null || true
  done <"$IGNORE_FILE"
}

sync_flake_lock_subset() {
  local base_lock_tmp
  local upstream_lock_tmp

  if ! git cat-file -e "${BASE_REMOTE_NAME}/${BASE_BRANCH}:flake.lock" 2>/dev/null; then
    return 1
  fi

  if ! git cat-file -e "${UPSTREAM_REMOTE_NAME}/${UPSTREAM_BRANCH}:flake.lock" 2>/dev/null; then
    return 1
  fi

  base_lock_tmp="$(mktemp)"
  upstream_lock_tmp="$(mktemp)"

  git show "${BASE_REMOTE_NAME}/${BASE_BRANCH}:flake.lock" >"$base_lock_tmp"
  git show "${UPSTREAM_REMOTE_NAME}/${UPSTREAM_BRANCH}:flake.lock" >"$upstream_lock_tmp"

  jq -S -n --argfile base "$base_lock_tmp" --argfile upstream "$upstream_lock_tmp" '
    reduce ($base | paths(scalars)) as $p (
      $base;
      if ($upstream | try (getpath($p) | true) catch false)
      then setpath($p; $upstream | getpath($p))
      else .
      end
    )
  ' >flake.lock

  rm -f "$base_lock_tmp" "$upstream_lock_tmp"

  git add flake.lock
  if git diff --cached --quiet -- flake.lock; then
    return 1
  fi

  return 0
}

set_remote "$UPSTREAM_REMOTE_NAME" "$UPSTREAM_REMOTE_URL"

git fetch "$BASE_REMOTE_NAME" "$BASE_BRANCH"
git fetch "$UPSTREAM_REMOTE_NAME" "$UPSTREAM_BRANCH"

git checkout -B "$SYNC_BRANCH" "$BASE_REMOTE_NAME/$BASE_BRANCH"

merge_base="$(git merge-base "$BASE_REMOTE_NAME/$BASE_BRANCH" "$UPSTREAM_REMOTE_NAME/$UPSTREAM_BRANCH")"
mapfile -t upstream_commits < <(
  git rev-list --reverse --first-parent "${merge_base}..${UPSTREAM_REMOTE_NAME}/${UPSTREAM_BRANCH}"
)

applied_commit_count=0
skipped_commit_count=0

for commit in "${upstream_commits[@]}"; do
  commit_parents=()
  read -r -a commit_parents <<<"$(git rev-list --parents -n 1 "$commit")"
  parent_count=$(( ${#commit_parents[@]} - 1 ))

  cherry_pick_args=(--no-commit)
  if (( parent_count > 1 )); then
    cherry_pick_args+=(--mainline 1)
  fi

  if ! git cherry-pick "${cherry_pick_args[@]}" "$commit"; then
    if [[ -z "$(git diff --name-only --diff-filter=U)" ]]; then
      git cherry-pick --abort || true
      skipped_commit_count=$((skipped_commit_count + 1))
      continue
    fi

    git cherry-pick --abort || true
    printf "Cherry-pick failed for commit %s\n" "$commit" >&2
    exit 1
  fi

  restore_ignored_paths

  if git diff --cached --quiet; then
    skipped_commit_count=$((skipped_commit_count + 1))
    git reset --hard HEAD
    continue
  fi

  original_message="$(git log -1 --format=%B "$commit")"
  commit_message="${original_message}

(cherry picked from commit ${commit})"

  GIT_AUTHOR_NAME="$(git log -1 --format=%an "$commit")" \
    GIT_AUTHOR_EMAIL="$(git log -1 --format=%ae "$commit")" \
    GIT_AUTHOR_DATE="$(git log -1 --format=%aI "$commit")" \
    git commit -m "$commit_message"

  applied_commit_count=$((applied_commit_count + 1))
done

if sync_flake_lock_subset; then
  git commit -m "flake.lock: sync subset from upstream ${UPSTREAM_BRANCH}"
  applied_commit_count=$((applied_commit_count + 1))
fi

needs_sync=false
if (( applied_commit_count > 0 )); then
  needs_sync=true
elif [[ "$FORCE_SYNC" == "true" ]]; then
  git commit --allow-empty -m "Sync upstream ${UPSTREAM_BRANCH} (filtered)"
  applied_commit_count=1
  needs_sync=true
fi

if [[ "$needs_sync" == "true" && "$DRY_RUN" != "true" ]]; then
  git push --force-with-lease "$BASE_REMOTE_NAME" "$SYNC_BRANCH"
fi

emit_output "merge_base" "$merge_base"
emit_output "upstream_commit_count" "${#upstream_commits[@]}"
emit_output "applied_commit_count" "$applied_commit_count"
emit_output "skipped_commit_count" "$skipped_commit_count"
emit_output "needs_sync" "$needs_sync"
