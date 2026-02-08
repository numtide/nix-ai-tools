#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="${SCRIPT_PATH:-$(pwd)/scripts/sync-upstream.sh}"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$expected" != "$actual" ]]; then
    printf "Assertion failed: %s\nExpected: %s\nActual: %s\n" "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_file_value() {
  local repo="$1"
  local ref="$2"
  local file="$3"
  local expected="$4"
  local message="$5"

  local value
  value="$(git -C "$repo" show "${ref}:${file}")"
  assert_eq "$expected" "$value" "$message"
}

new_fixture() {
  local fixture
  fixture="$(mktemp -d)"

  local origin_bare="$fixture/origin.git"
  local upstream_bare="$fixture/upstream.git"
  local seed="$fixture/seed"
  local fork="$fixture/fork"
  local upstream_work="$fixture/upstream-work"

  git init --bare --initial-branch main "$origin_bare" >/dev/null
  git init --bare --initial-branch main "$upstream_bare" >/dev/null

  git init --initial-branch main "$seed" >/dev/null
  git -C "$seed" config user.name "Fixture Seeder"
  git -C "$seed" config user.email "seeder@example.com"

  mkdir -p "$seed/.github"
  printf "base\n" >"$seed/tracked.txt"
  printf "base\n" >"$seed/ignored.txt"
  printf "ignored.txt\n" >"$seed/.github/upstream-sync-ignore.txt"

  git -C "$seed" add -A
  git -C "$seed" commit -m "Initial commit" >/dev/null
  git -C "$seed" remote add origin "$origin_bare"
  git -C "$seed" remote add upstream "$upstream_bare"
  git -C "$seed" push origin main >/dev/null
  git -C "$seed" push upstream main >/dev/null

  git clone "$origin_bare" "$fork" >/dev/null
  git -C "$fork" checkout main >/dev/null
  git -C "$fork" config user.name "Fork User"
  git -C "$fork" config user.email "fork@example.com"

  git clone "$upstream_bare" "$upstream_work" >/dev/null
  git -C "$upstream_work" checkout main >/dev/null
  git -C "$upstream_work" config user.name "Upstream User"
  git -C "$upstream_work" config user.email "upstream@example.com"

  printf "%s\n%s\n%s\n" "$fixture" "$fork" "$upstream_work"
}

add_upstream_commit() {
  local upstream_repo="$1"
  local file="$2"
  local content="$3"
  local message="$4"

  printf "%s\n" "$content" >"$upstream_repo/$file"
  git -C "$upstream_repo" add "$file"
  git -C "$upstream_repo" commit -m "$message" >/dev/null
  git -C "$upstream_repo" push origin main >/dev/null
}

run_sync() {
  local fork_repo="$1"
  local upstream_bare="$2"
  local output_file="$3"

  (
    cd "$fork_repo"
    UPSTREAM_REMOTE_URL="$upstream_bare" \
      BASE_BRANCH=main \
      UPSTREAM_BRANCH=main \
      SYNC_BRANCH=upstream-sync \
      IGNORE_FILE=.github/upstream-sync-ignore.txt \
      DRY_RUN=true \
      GITHUB_OUTPUT="$output_file" \
      bash "$SCRIPT_PATH" >/dev/null
  )
}

test_non_ignored_commit_is_applied() {
  local fixture fork upstream_work out
  mapfile -t values < <(new_fixture)
  fixture="${values[0]}"
  fork="${values[1]}"
  upstream_work="${values[2]}"
  out="$fixture/out.txt"

  add_upstream_commit "$upstream_work" "tracked.txt" "upstream-change" "Update tracked file"
  run_sync "$fork" "$fixture/upstream.git" "$out"

  source "$out"
  assert_eq "true" "$needs_sync" "non-ignored upstream change should need sync"
  assert_eq "1" "$applied_commit_count" "one commit should be applied"
  assert_eq "0" "$skipped_commit_count" "no commits should be skipped"
  assert_file_value "$fork" "upstream-sync" "tracked.txt" "upstream-change" "tracked file should be updated"
}

test_ignored_only_commit_is_skipped() {
  local fixture fork upstream_work out
  mapfile -t values < <(new_fixture)
  fixture="${values[0]}"
  fork="${values[1]}"
  upstream_work="${values[2]}"
  out="$fixture/out.txt"

  add_upstream_commit "$upstream_work" "ignored.txt" "ignored-upstream" "Update ignored file"
  run_sync "$fork" "$fixture/upstream.git" "$out"

  source "$out"
  assert_eq "false" "$needs_sync" "ignored-only commit should not need sync"
  assert_eq "0" "$applied_commit_count" "ignored-only commit should not be applied"
  assert_eq "1" "$skipped_commit_count" "ignored-only commit should be skipped"
}

test_mixed_commit_filters_ignored_paths() {
  local fixture fork upstream_work out
  mapfile -t values < <(new_fixture)
  fixture="${values[0]}"
  fork="${values[1]}"
  upstream_work="${values[2]}"
  out="$fixture/out.txt"

  printf "mixed-tracked\n" >"$upstream_work/tracked.txt"
  printf "mixed-ignored\n" >"$upstream_work/ignored.txt"
  git -C "$upstream_work" add tracked.txt ignored.txt
  git -C "$upstream_work" commit -m "Mixed change" >/dev/null
  git -C "$upstream_work" push origin main >/dev/null

  run_sync "$fork" "$fixture/upstream.git" "$out"

  source "$out"
  assert_eq "true" "$needs_sync" "mixed commit should need sync"
  assert_eq "1" "$applied_commit_count" "mixed commit should still apply"
  assert_file_value "$fork" "upstream-sync" "tracked.txt" "mixed-tracked" "tracked file should change"
  assert_file_value "$fork" "upstream-sync" "ignored.txt" "base" "ignored file should remain unchanged"
}

test_first_parent_merge_commit_is_applied() {
  local fixture fork upstream_work out
  mapfile -t values < <(new_fixture)
  fixture="${values[0]}"
  fork="${values[1]}"
  upstream_work="${values[2]}"
  out="$fixture/out.txt"

  git -C "$upstream_work" checkout -b feature-sync-test >/dev/null
  printf "merged-change\n" >"$upstream_work/tracked.txt"
  git -C "$upstream_work" add tracked.txt
  git -C "$upstream_work" commit -m "Feature branch tracked update" >/dev/null
  git -C "$upstream_work" checkout main >/dev/null
  git -C "$upstream_work" merge --no-ff feature-sync-test -m "Merge feature-sync-test" >/dev/null
  git -C "$upstream_work" push origin main >/dev/null

  run_sync "$fork" "$fixture/upstream.git" "$out"

  source "$out"
  assert_eq "true" "$needs_sync" "merge commit should still need sync"
  assert_eq "1" "$applied_commit_count" "merge commit should apply as first-parent diff"
  assert_file_value "$fork" "upstream-sync" "tracked.txt" "merged-change" "merge commit diff should be applied"
}

test_conflict_exits_nonzero() {
  local fixture fork upstream_work
  mapfile -t values < <(new_fixture)
  fixture="${values[0]}"
  fork="${values[1]}"
  upstream_work="${values[2]}"

  printf "fork-change\n" >"$fork/tracked.txt"
  git -C "$fork" add tracked.txt
  git -C "$fork" commit -m "Fork diverges" >/dev/null
  git -C "$fork" push origin main >/dev/null

  printf "upstream-change\n" >"$upstream_work/tracked.txt"
  git -C "$upstream_work" add tracked.txt
  git -C "$upstream_work" commit -m "Upstream diverges" >/dev/null
  git -C "$upstream_work" push origin main >/dev/null

  local out="$fixture/out.txt"
  set +e
  (
    cd "$fork"
    UPSTREAM_REMOTE_URL="$fixture/upstream.git" \
      BASE_BRANCH=main \
      UPSTREAM_BRANCH=main \
      SYNC_BRANCH=upstream-sync \
      IGNORE_FILE=.github/upstream-sync-ignore.txt \
      DRY_RUN=true \
      GITHUB_OUTPUT="$out" \
      bash "$SCRIPT_PATH" >/dev/null
  )
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    printf "Expected conflict case to fail, but it succeeded.\n" >&2
    exit 1
  fi
}

test_non_ignored_commit_is_applied
test_ignored_only_commit_is_skipped
test_mixed_commit_filters_ignored_paths
test_first_parent_merge_commit_is_applied
test_conflict_exits_nonzero

printf "All sync-upstream tests passed.\n"
