#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

repo_config_jq() {
  ensure_file "$REPO_CONFIG_FILE"
  jq -r "$1" "$REPO_CONFIG_FILE"
}

repo_exists() {
  local alias="$1"
  jq -e --arg alias "$alias" '.repositories[$alias]' "$REPO_CONFIG_FILE" >/dev/null
}

resolve_repo_alias() {
  local jira_key="${1:-}"
  local explicit_alias="${2:-}"
  local alias=""
  local project_key=""

  ensure_file "$REPO_CONFIG_FILE"
  require_command jq

  if [[ -n "$explicit_alias" ]]; then
    repo_exists "$explicit_alias" || fail "Repository alias not found in config: ${explicit_alias}"
    printf '%s\n' "$explicit_alias"
    return 0
  fi

  if [[ -n "$jira_key" ]]; then
    project_key="$(jira_project_key "$jira_key")"
    alias="$(jq -r --arg key "$project_key" '.project_key_map[$key] // empty' "$REPO_CONFIG_FILE")"
  fi

  if [[ -z "$alias" ]]; then
    alias="$(jq -r '.default_alias // empty' "$REPO_CONFIG_FILE")"
  fi

  [[ -n "$alias" ]] || fail "Could not resolve repository alias from Jira key or default_alias"
  repo_exists "$alias" || fail "Resolved repository alias not found in config: ${alias}"
  printf '%s\n' "$alias"
}

repo_relative_path() {
  local alias="$1"
  jq -r --arg alias "$alias" '.repositories[$alias].relative_path // empty' "$REPO_CONFIG_FILE"
}

repo_path() {
  local alias="$1"
  local relative_path
  relative_path="$(repo_relative_path "$alias")"
  [[ -n "$relative_path" ]] || fail "Repository ${alias} is missing relative_path"
  [[ "$relative_path" != "replace-with-your-repo" ]] || fail "Repository ${alias} still uses the placeholder relative_path"
  printf '%s/%s\n' "${PROJECTS_MOUNT%/}" "${relative_path#./}"
}

repo_base_branch() {
  local alias="$1"
  local value
  value="$(jq -r --arg alias "$alias" '.repositories[$alias].base_branch // empty' "$REPO_CONFIG_FILE")"
  if [[ -n "$value" && "$value" != "null" ]]; then
    printf '%s\n' "$value"
    return 0
  fi
  printf '%s\n' "${DEFAULT_BASE_BRANCH:-main}"
}

repo_branch_prefix() {
  local alias="$1"
  local value
  value="$(jq -r --arg alias "$alias" '.repositories[$alias].branch_prefix // empty' "$REPO_CONFIG_FILE")"
  if [[ -n "$value" && "$value" != "null" ]]; then
    printf '%s\n' "$value"
    return 0
  fi
  printf '%s\n' "${WORKTREE_BRANCH_PREFIX:-feature}"
}
