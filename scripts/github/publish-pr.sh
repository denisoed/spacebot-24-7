#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

jira_key=""
worktree_path=""
base_branch=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jira-key)
      jira_key="${2:-}"
      shift 2
      ;;
    --worktree)
      worktree_path="${2:-}"
      shift 2
      ;;
    --base-branch)
      base_branch="${2:-}"
      shift 2
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$jira_key" ]] || fail "Usage: publish-pr.sh --jira-key PROJ-123 --worktree /workspace/worktrees/PROJ-123 [--base-branch main]"
[[ -n "$worktree_path" ]] || fail "Usage: publish-pr.sh --jira-key PROJ-123 --worktree /workspace/worktrees/PROJ-123 [--base-branch main]"

require_command gh
require_command git
require_command jq
require_env JIRA_BASE_URL

[[ -d "$worktree_path" ]] || fail "Worktree does not exist: ${worktree_path}"
git -C "$worktree_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Worktree is not a git repository: ${worktree_path}"

branch_name="$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD)"
if [[ -z "$base_branch" ]]; then
  base_branch="$(git -C "$worktree_path" remote show origin | awk '/HEAD branch/ {print $NF}' | head -n1)"
  base_branch="${base_branch:-${DEFAULT_BASE_BRANCH:-main}}"
fi

issue_json="$("${SCRIPT_DIR}/../jira/get-issue.sh" --jira-key "$jira_key" --format json)"
summary="$(jq -r '.summary' <<<"$issue_json")"
issue_url="$(jq -r '.url' <<<"$issue_json")"

git -C "$worktree_path" add -A

if ! git -C "$worktree_path" diff --cached --quiet; then
  commit_title="${jira_key}: ${summary}"
  git -C "$worktree_path" commit -m "$commit_title" >/dev/null
fi

git -C "$worktree_path" push -u origin "$branch_name" >/dev/null

existing_url="$(
  cd "$worktree_path"
  gh pr view "$branch_name" --json url --jq '.url' 2>/dev/null || true
)"
if [[ -n "$existing_url" ]]; then
  jq -n \
    --arg jira_key "$jira_key" \
    --arg branch_name "$branch_name" \
    --arg base_branch "$base_branch" \
    --arg worktree_path "$worktree_path" \
    --arg pr_url "$existing_url" \
    '{jira_key: $jira_key, branch_name: $branch_name, base_branch: $base_branch, worktree_path: $worktree_path, pr_url: $pr_url, created: false}'
  exit 0
fi

body_file="$(mktemp)"
{
  printf '## Jira\n\n'
  printf -- '- Issue: [%s](%s)\n' "$jira_key" "$issue_url"
  printf -- '- Summary: %s\n\n' "$summary"
  printf '## Changes\n\n'
  printf -- '- Implemented the requested scope for `%s`.\n\n' "$jira_key"
  printf '## Validation\n\n'
  printf -- '- [ ] Local validation completed\n'
  printf -- '- [ ] Ready for reviewer verification\n'
} >"$body_file"

pr_url="$(
  cd "$worktree_path"
  gh pr create \
    --base "$base_branch" \
    --head "$branch_name" \
    --title "${jira_key}: ${summary}" \
    --body-file "$body_file"
)"

rm -f "$body_file"

jq -n \
  --arg jira_key "$jira_key" \
  --arg branch_name "$branch_name" \
  --arg base_branch "$base_branch" \
  --arg worktree_path "$worktree_path" \
  --arg pr_url "$pr_url" \
  '{jira_key: $jira_key, branch_name: $branch_name, base_branch: $base_branch, worktree_path: $worktree_path, pr_url: $pr_url, created: true}'
