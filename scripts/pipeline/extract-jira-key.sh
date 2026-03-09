#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

message="${1:-}"

if [[ -z "$message" && ! -t 0 ]]; then
  message="$(cat)"
fi

[[ -n "$message" ]] || fail "Usage: extract-jira-key.sh 'message with PROJ-123'"

jira_key="$(printf '%s\n' "$message" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -n1 || true)"
[[ -n "$jira_key" ]] || fail "No Jira issue key found in message"

printf '%s\n' "$jira_key"
