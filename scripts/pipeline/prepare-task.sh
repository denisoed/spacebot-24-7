#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=../lib/repos.sh
source "${SCRIPT_DIR}/../lib/repos.sh"

message=""
repo_alias=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message)
      message="${2:-}"
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

[[ -n "$message" ]] || fail "Usage: prepare-task.sh --message 'PROJ-123 implement X'"

require_command jq

jira_key="$("${SCRIPT_DIR}/extract-jira-key.sh" "$message")"
issue_json="$("${SCRIPT_DIR}/../jira/get-issue.sh" --jira-key "$jira_key" --format json)"
worktree_args=(--jira-key "$jira_key")
if [[ -n "$repo_alias" ]]; then
  worktree_args+=(--repo-alias "$repo_alias")
fi
worktree_json="$("${SCRIPT_DIR}/../git/ensure-worktree.sh" "${worktree_args[@]}")"

repo_alias_value="$(jq -r '.repo_alias' <<<"$worktree_json")"
worktree_path="$(jq -r '.worktree_path' <<<"$worktree_json")"
branch_name="$(jq -r '.branch_name' <<<"$worktree_json")"
base_branch="$(jq -r '.base_branch' <<<"$worktree_json")"

context_dir="${worktree_path}/.spacebot"
context_file="${worktree_path}/TASK_CONTEXT.md"
mkdir -p "$context_dir"

exclude_file="$(git -C "$worktree_path" rev-parse --git-path info/exclude)"
touch "$exclude_file"
grep -qxF '.spacebot/' "$exclude_file" || printf '%s\n' '.spacebot/' >>"$exclude_file"
grep -qxF 'TASK_CONTEXT.md' "$exclude_file" || printf '%s\n' 'TASK_CONTEXT.md' >>"$exclude_file"

printf '%s\n' "$issue_json" >"${context_dir}/jira-issue.json"
printf '%s\n' "$message" >"${context_dir}/telegram-request.txt"

{
  printf '# Task Context\n\n'
  printf '## Telegram Request\n\n%s\n\n' "$message"
  printf '## Repository\n\n'
  printf -- '- Alias: %s\n' "$repo_alias_value"
  printf -- '- Worktree: %s\n' "$worktree_path"
  printf -- '- Branch: %s\n' "$branch_name"
  printf -- '- Base branch: %s\n\n' "$base_branch"
  printf '## Jira\n\n'
  "${SCRIPT_DIR}/../jira/get-issue.sh" --jira-key "$jira_key" --format markdown
  printf '\n'
} >"$context_file"

jq -n \
  --arg message "$message" \
  --arg jira_key "$jira_key" \
  --arg repo_alias "$repo_alias_value" \
  --arg worktree_path "$worktree_path" \
  --arg branch_name "$branch_name" \
  --arg base_branch "$base_branch" \
  --arg context_file "$context_file" \
  --argjson issue "$issue_json" \
  '{
    message: $message,
    jira_key: $jira_key,
    repo_alias: $repo_alias,
    worktree_path: $worktree_path,
    branch_name: $branch_name,
    base_branch: $base_branch,
    context_file: $context_file,
    issue: $issue
  }'
