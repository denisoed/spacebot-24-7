#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

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

[[ -n "$message" ]] || fail "Usage: run-task.sh --message 'PROJ-123 implement X'"

require_command jq
require_command opencode

"${SCRIPT_DIR}/../validate-env.sh" >/dev/null

prepare_args=(--message "$message")
if [[ -n "$repo_alias" ]]; then
  prepare_args+=(--repo-alias "$repo_alias")
fi
prepare_json="$("${SCRIPT_DIR}/prepare-task.sh" "${prepare_args[@]}")"
worktree_path="$(jq -r '.worktree_path' <<<"$prepare_json")"
jira_key="$(jq -r '.jira_key' <<<"$prepare_json")"
base_branch="$(jq -r '.base_branch' <<<"$prepare_json")"
context_file="$(jq -r '.context_file' <<<"$prepare_json")"
issue_summary="$(jq -r '.issue.summary' <<<"$prepare_json")"

prompt_file="$(mktemp)"
{
  printf 'Work inside the repository at: %s\n\n' "$worktree_path"
  printf 'Jira issue: %s\n' "$jira_key"
  printf 'Issue summary: %s\n\n' "$issue_summary"
  printf 'Primary request from Telegram:\n%s\n\n' "$message"
  printf 'Open and follow TASK_CONTEXT.md before making changes.\n'
  printf 'Use Atlassian MCP only if it is already authenticated; otherwise rely on TASK_CONTEXT.md.\n'
  printf 'Do the implementation, run relevant validation, and stop without creating commits or pull requests.\n'
} >"$prompt_file"

(
  cd "$worktree_path"
  opencode run "$(<"$prompt_file")"
)

rm -f "$prompt_file"

publish_json="$("${SCRIPT_DIR}/../github/publish-pr.sh" --jira-key "$jira_key" --worktree "$worktree_path" --base-branch "$base_branch")"

jq -n \
  --argjson prepare "$prepare_json" \
  --argjson publish "$publish_json" \
  '{prepare: $prepare, publish: $publish}'
