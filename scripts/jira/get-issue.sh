#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

format="json"
jira_key=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jira-key)
      jira_key="${2:-}"
      shift 2
      ;;
    --format)
      format="${2:-json}"
      shift 2
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$jira_key" ]] || fail "Usage: get-issue.sh --jira-key PROJ-123 [--format json|markdown]"

require_command curl
require_command jq
require_env JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN

base_url="${JIRA_BASE_URL%/}"
issue_url="${base_url}/rest/api/3/issue/${jira_key}?fields=summary,description,status,issuetype,priority,assignee,labels"

response_file="$(mktemp)"
status_code="$(curl -sS -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -H 'Accept: application/json' \
  -o "$response_file" \
  -w '%{http_code}' \
  "$issue_url")"

if [[ "$status_code" != "200" ]]; then
  error_payload="$(cat "$response_file")"
  rm -f "$response_file"
  fail "Jira API request failed with HTTP ${status_code}: ${error_payload}"
fi

case "$format" in
  json)
    jq --arg base_url "$base_url" '
      def walk_text(node):
        if node == null then ""
        elif (node | type) == "string" then node
        elif (node | type) == "array" then (node | map(walk_text(.)) | join("\n"))
        elif (node | type) == "object" then
          if node.text then node.text
          elif node.content then walk_text(node.content)
          else ""
          end
        else ""
        end;
      {
        key: .key,
        url: ($base_url + "/browse/" + .key),
        summary: (.fields.summary // ""),
        issue_type: (.fields.issuetype.name // ""),
        status: (.fields.status.name // ""),
        priority: (.fields.priority.name // ""),
        assignee: (.fields.assignee.displayName // ""),
        labels: (.fields.labels // []),
        description_text: (walk_text(.fields.description) | gsub("\n{3,}"; "\n\n"))
      }
    ' "$response_file"
    ;;
  markdown)
    jq -r --arg base_url "$base_url" '
      def walk_text(node):
        if node == null then ""
        elif (node | type) == "string" then node
        elif (node | type) == "array" then (node | map(walk_text(.)) | join("\n"))
        elif (node | type) == "object" then
          if node.text then node.text
          elif node.content then walk_text(node.content)
          else ""
          end
        else ""
        end;
      [
        "# Jira Issue",
        "",
        "- Key: " + .key,
        "- URL: " + ($base_url + "/browse/" + .key),
        "- Summary: " + (.fields.summary // ""),
        "- Status: " + (.fields.status.name // ""),
        "- Type: " + (.fields.issuetype.name // ""),
        "- Priority: " + (.fields.priority.name // ""),
        "- Assignee: " + (.fields.assignee.displayName // "unassigned"),
        "",
        "## Description",
        "",
        (walk_text(.fields.description) // "")
      ] | join("\n")
    ' "$response_file"
    ;;
  *)
    rm -f "$response_file"
    fail "Unsupported format: ${format}"
    ;;
esac

rm -f "$response_file"
