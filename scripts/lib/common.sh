#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"
REPO_CONFIG_FILE="${REPO_CONFIG_FILE:-${CONFIG_DIR}/repositories.json}"
PROJECTS_MOUNT="${PROJECTS_MOUNT:-/workspace/projects}"
WORKTREE_ROOT="${WORKTREE_ROOT:-/workspace/worktrees}"

log() {
  printf '[%s] %s\n' "$(basename "$0")" "$*" >&2
}

fail() {
  printf '[%s] %s\n' "$(basename "$0")" "$*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
}

require_env() {
  local missing=()
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      missing+=("$name")
    fi
  done

  if ((${#missing[@]} > 0)); then
    fail "Missing required environment variables: ${missing[*]}"
  fi
}

ensure_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Required file not found: ${path}"
}

json_escape() {
  jq -Rn --arg value "$1" '$value'
}

jira_project_key() {
  local jira_key="$1"
  printf '%s\n' "${jira_key%%-*}"
}

normalize_worktree_name() {
  local jira_key="$1"
  local repo_alias="$2"
  local template="${WORKTREE_NAME_TEMPLATE:-{jira_key}}"

  template="${template//\{jira_key\}/${jira_key}}"
  template="${template//\{repo_alias\}/${repo_alias}}"
  printf '%s\n' "$template"
}
