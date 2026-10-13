#!/usr/bin/env bash
# Simulates an AI/MCP service querying Elasticsearch using a user-specific API key.
# This is not a real MCP server or AI assistant — it demonstrates the security pattern.
#
# Usage: bash scripts/fake-ai-mcp-query.sh <user> <index>
#   e.g.: bash scripts/fake-ai-mcp-query.sh alice alice-reports   # allowed
#         bash scripts/fake-ai-mcp-query.sh alice alice-logs       # denied — logs outside AI/MCP scope
#         bash scripts/fake-ai-mcp-query.sh bob   bob-reports      # allowed
#         bash scripts/fake-ai-mcp-query.sh bob   alice-logs       # denied — logs outside AI/MCP scope
set -euo pipefail

USER="${1:-}"
INDEX="${2:-}"

if [ -z "$USER" ] || [ -z "$INDEX" ]; then
  printf 'Usage: %s <user> <index>\n' "$0"
  printf '  e.g.: %s alice alice-reports\n' "$0"
  exit 1
fi

ES="${ES:-https://localhost:19200}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(dirname "$SCRIPT_DIR")"
KEY_FILE="${EXAMPLE_DIR}/.runtime-keys/${USER}.key"

if [ ! -f "$KEY_FILE" ]; then
  printf '  [fake-ai-mcp] ERROR: No API key found for user "%s"\n' "$USER"
  printf '  [fake-ai-mcp] Run scripts/demo.sh first to generate API keys.\n'
  exit 1
fi

API_KEY=$(cat "$KEY_FILE")

printf '  [fake-ai-mcp] user=%-8s index=%s\n' "$USER" "$INDEX"
printf '  [fake-ai-mcp] Authorization: ApiKey <encoded-key>\n'
printf '  [fake-ai-mcp] GET %s/%s/_search\n' "$ES" "$INDEX"

RESPONSE=$(curl -k -s -w '\n%{http_code}' \
  -H "Authorization: ApiKey ${API_KEY}" \
  "${ES}/${INDEX}/_search")

HTTP_CODE=$(printf '%s' "$RESPONSE" | tail -n1)
BODY=$(printf '%s' "$RESPONSE" | sed '$d')

case "$HTTP_CODE" in
  200)
    printf '  [fake-ai-mcp] \033[32mSUCCESS\033[0m (HTTP %s)\n' "$HTTP_CODE"
    printf '%s\n' "$BODY" \
      | jq -r '.hits.hits[] | "    hit → \(._source | tojson)"' 2>/dev/null \
      || printf '%s\n' "$BODY"
    ;;
  403)
    printf '  [fake-ai-mcp] \033[31mDENIED\033[0m (HTTP %s) — access forbidden\n' "$HTTP_CODE"
    REASON=$(printf '%s\n' "$BODY" \
      | jq -r '.error.reason // .error.root_cause[0].reason // "no reason in response"' 2>/dev/null \
      || printf 'could not parse response')
    printf '    reason: %s\n' "$REASON"
    ;;
  401)
    printf '  [fake-ai-mcp] \033[31mREJECTED\033[0m (HTTP %s) — invalid or revoked API key\n' "$HTTP_CODE"
    ;;
  *)
    printf '  [fake-ai-mcp] UNEXPECTED (HTTP %s)\n' "$HTTP_CODE"
    printf '%s\n' "$BODY"
    ;;
esac
