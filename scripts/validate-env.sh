#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/repos.sh
source "${SCRIPT_DIR}/lib/repos.sh"

require_command curl
require_command gh
require_command git
require_command jq

require_env \
  OPENROUTER_API_KEY \
  TELEGRAM_BOT_TOKEN \
  TELEGRAM_PRIMARY_CHAT_ID \
  JIRA_BASE_URL \
  JIRA_EMAIL \
  JIRA_API_TOKEN \
  GH_TOKEN

ensure_file "$REPO_CONFIG_FILE"

default_alias="$(repo_config_jq '.default_alias // empty')"
[[ -n "$default_alias" ]] || fail "default_alias is missing in ${REPO_CONFIG_FILE}"

repo_path_value="$(repo_path "$default_alias")"
[[ -d "$repo_path_value" ]] || fail "Configured repository path does not exist: ${repo_path_value}"
git -C "$repo_path_value" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Configured repository is not a git repository: ${repo_path_value}"

mkdir -p "$WORKTREE_ROOT"

if [[ -n "${OPENCODE_PATH:-}" ]]; then
  [[ -x "${OPENCODE_PATH}" ]] || fail "OPENCODE_PATH is not executable: ${OPENCODE_PATH}"
fi

printf '%s\n' "OK"
