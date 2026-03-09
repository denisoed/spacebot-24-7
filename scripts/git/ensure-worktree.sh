#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=../lib/repos.sh
source "${SCRIPT_DIR}/../lib/repos.sh"

jira_key=""
repo_alias=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jira-key)
      jira_key="${2:-}"
      shift 2
      ;;
    --repo-alias)
      repo_alias="${2:-}"
      shift 2
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$jira_key" ]] || fail "Usage: ensure-worktree.sh --jira-key PROJ-123 [--repo-alias alias]"

require_command git
require_command jq

repo_alias="$(resolve_repo_alias "$jira_key" "$repo_alias")"
repo_path_value="$(repo_path "$repo_alias")"
base_branch="$(repo_base_branch "$repo_alias")"
branch_prefix="$(repo_branch_prefix "$repo_alias")"
branch_name="${branch_prefix}/${jira_key}"
worktree_name="$(normalize_worktree_name "$jira_key" "$repo_alias")"
worktree_path="${WORKTREE_ROOT%/}/${worktree_name}"

[[ -d "$repo_path_value" ]] || fail "Repository path does not exist: ${repo_path_value}"
git -C "$repo_path_value" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Repository is not a git repository: ${repo_path_value}"

mkdir -p "$WORKTREE_ROOT"
git -C "$repo_path_value" fetch origin "$base_branch" --prune >/dev/null 2>&1 || true

if [[ -d "$worktree_path/.git" || -f "$worktree_path/.git" ]]; then
  current_branch="$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD)"
  jq -n \
    --arg jira_key "$jira_key" \
    --arg repo_alias "$repo_alias" \
    --arg repo_path "$repo_path_value" \
    --arg worktree_path "$worktree_path" \
    --arg base_branch "$base_branch" \
    --arg branch_name "$current_branch" \
    '{jira_key: $jira_key, repo_alias: $repo_alias, repo_path: $repo_path, worktree_path: $worktree_path, base_branch: $base_branch, branch_name: $branch_name, reused: true}'
  exit 0
fi

if git -C "$repo_path_value" show-ref --verify --quiet "refs/heads/${branch_name}"; then
  git -C "$repo_path_value" worktree add "$worktree_path" "$branch_name" >/dev/null
else
  if git -C "$repo_path_value" show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
    git -C "$repo_path_value" worktree add -b "$branch_name" "$worktree_path" "origin/${base_branch}" >/dev/null
  else
    git -C "$repo_path_value" worktree add -b "$branch_name" "$worktree_path" "$base_branch" >/dev/null
  fi
fi

jq -n \
  --arg jira_key "$jira_key" \
  --arg repo_alias "$repo_alias" \
  --arg repo_path "$repo_path_value" \
  --arg worktree_path "$worktree_path" \
  --arg base_branch "$base_branch" \
  --arg branch_name "$branch_name" \
  '{jira_key: $jira_key, repo_alias: $repo_alias, repo_path: $repo_path, worktree_path: $worktree_path, base_branch: $base_branch, branch_name: $branch_name, reused: false}'
