#!/usr/bin/env bash
# Full lifecycle demo: create API keys, run AI/MCP queries, test write restriction,
# revoke a key, verify rejection, and show where audit events land.
set -euo pipefail

ES="${ES:-https://localhost:19200}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="${EXAMPLE_DIR}/.runtime-keys"

mkdir -p "$KEYS_DIR"

sep()  { printf '\n'; printf '═%.0s' {1..60}; printf '\n\n'; }
step() { printf '\n\033[1m  → %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$*"; }
fail() { printf '  \033[31m✗ %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

sep
printf '  AI/MCP API Keys Demo\n'
printf '  ReadonlyREST + Elasticsearch Native API Keys\n'
sep

# --- Create Alice's API key ---
# Alice creates her own key using her own credentials.
# Access scope and read-only enforcement are governed entirely by the ROR ACL block.
step "Creating Alice's AI/MCP API key  [expires in 1 day]"
ALICE_RESPONSE=$(curl -k -s -u alice:alice \
  -X POST "${ES}/_security/api_key" \
  -H 'Content-Type: application/json' \
  -d '{"name":"alice-ai-mcp","expiration":"1d"}')
ALICE_KEY_ID=$(printf '%s' "$ALICE_RESPONSE" | jq -r '.id')
printf '%s' "$ALICE_RESPONSE" | jq -r '.encoded' > "${KEYS_DIR}/alice.key"
info "Key id:   ${ALICE_KEY_ID}"
info "Key name: $(printf '%s' "$ALICE_RESPONSE" | jq -r '.name')"
ok "Alice's API key created and saved to .runtime-keys/alice.key"

# --- Create Bob's API key ---
# Bob creates his own key using his own credentials.
# Access scope and read-only enforcement are governed entirely by the ROR ACL block.
step "Creating Bob's AI/MCP API key  [expires in 1 day]"
BOB_RESPONSE=$(curl -k -s -u bob:bob \
  -X POST "${ES}/_security/api_key" \
  -H 'Content-Type: application/json' \
  -d '{"name":"bob-ai-mcp","expiration":"1d"}')
BOB_KEY_ID=$(printf '%s' "$BOB_RESPONSE" | jq -r '.id')
printf '%s' "$BOB_RESPONSE" | jq -r '.encoded' > "${KEYS_DIR}/bob.key"
info "Key id:   ${BOB_KEY_ID}"
info "Key name: $(printf '%s' "$BOB_RESPONSE" | jq -r '.name')"
ok "Bob's API key created and saved to .runtime-keys/bob.key"

sep
printf '  Query scenarios via fake AI/MCP service\n'
sep

FAKE_AI="${SCRIPT_DIR}/fake-ai-mcp-query.sh"

step "Scenario 1: Alice AI/MCP queries alice-reports  [expect: allowed]"
bash "$FAKE_AI" alice alice-reports

step "Scenario 2: Alice AI/MCP queries alice-logs     [expect: denied — logs outside AI/MCP scope]"
bash "$FAKE_AI" alice alice-logs

step "Scenario 3: Bob AI/MCP queries bob-reports      [expect: allowed]"
bash "$FAKE_AI" bob bob-reports

step "Scenario 4: Bob AI/MCP queries alice-logs       [expect: denied — logs outside AI/MCP scope]"
bash "$FAKE_AI" bob alice-logs

sep
printf '  Write restriction scenarios\n'
sep

step "Scenario 5: Alice AI/MCP writes to alice-reports  [expect: denied — read-only]"
ALICE_KEY=$(cat "${KEYS_DIR}/alice.key")
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: ApiKey ${ALICE_KEY}" \
  -H 'Content-Type: application/json' \
  -X POST "${ES}/alice-reports/_doc" \
  -d '{"message":"unauthorized write attempt"}')
if [ "$HTTP_CODE" = "403" ]; then
  ok "Write blocked (HTTP 403) — ROR read-only action enforcement works"
else
  fail "Unexpected HTTP ${HTTP_CODE} (expected 403)"
fi

step "Scenario 6: Bob AI/MCP writes to bob-reports    [expect: denied — read-only]"
BOB_KEY=$(cat "${KEYS_DIR}/bob.key")
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: ApiKey ${BOB_KEY}" \
  -H 'Content-Type: application/json' \
  -X POST "${ES}/bob-reports/_doc" \
  -d '{"message":"unauthorized write attempt"}')
if [ "$HTTP_CODE" = "403" ]; then
  ok "Write blocked (HTTP 403) — ROR read-only action enforcement works"
else
  fail "Unexpected HTTP ${HTTP_CODE} (expected 403)"
fi

sep
printf '  API key revocation\n'
sep

step "Revoking Alice's API key using her own credentials  [id: ${ALICE_KEY_ID}]"
REVOKE_RESPONSE=$(curl -k -s -u alice:alice \
  -X DELETE "${ES}/_security/api_key" \
  -H 'Content-Type: application/json' \
  -d "{\"ids\":[\"${ALICE_KEY_ID}\"]}")
INVALIDATED=$(printf '%s' "$REVOKE_RESPONSE" | jq -r '.invalidated // 0')
info "Keys invalidated: ${INVALIDATED}"
ok "Alice's API key revoked"

step "Verifying revoked key is rejected  [expect: 403]"
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: ApiKey ${ALICE_KEY}" \
  "${ES}/alice-reports/_search")
if [ "$HTTP_CODE" = "403" ]; then
  ok "Revoked key rejected (HTTP 403) — revocation confirmed"
else
  fail "Unexpected HTTP ${HTTP_CODE} (expected 403)"
fi

sep
printf '  Audit log\n'
sep

info "ROR writes an audit event for every request to the readonlyrest_audit-* index."
info "The index pattern was created automatically. Open Kibana Discover to explore:"
info ""
info "  URL:      https://localhost:15601/s/default/app/discover"
info "  Login:    admin:admin"
info "  Pattern:  readonlyrest_audit-*"
info ""
info "Audit fields visible in this example:"
info "  user      — username assigned to the request (ai-mcp for API key requests)"
info "  acl_block — which ROR ACL block matched"
info "  action    — Elasticsearch action (e.g. indices:data/read/search)"
info "  indices   — target indices"
info "  type      — ALLOWED or FORBIDDEN"

sep
printf '  Demo complete.\n'
sep
