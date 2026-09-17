#!/bin/bash -x
#
# One-shot initializer: mints an Elasticsearch API key for the MCP server and
# writes it where the mcp-server container's `.env` loader (dotenvy) will find
# it. Runs once and exits so Docker marks it "completed"; mcp-server depends on
# this container completing successfully before it starts.

ES_URL="https://es-ror:9200"

# Wrapper around curl that prints the HTTP status code and fails loudly on
# non-2xx responses so the script exits at the first failing API call.
check_curl() {
  local description="$1"
  shift

  echo "Executing: $description"

  local response http_code body
  response=$(curl -w "\n%{http_code}" "$@")
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  echo "Response body: $body"
  echo "HTTP Status: $http_code"

  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "OK: $description (HTTP $http_code)"
    RESPONSE_BODY="$body"
    return 0
  else
    echo "FAILED: $description (HTTP $http_code)"
    return 1
  fi
}

# es-ror is already known-healthy (depends_on: condition: service_healthy),
# but ROR's own settings reload can lag a couple of seconds behind the ES
# healthcheck, so retry the first call a few times before giving up.
ATTEMPTS=0
until check_curl "Create ES API key for the MCP server" \
  -s -k -u admin:admin \
  -XPOST -H "Content-type: application/json" \
  "$ES_URL/_security/api_key" \
  -d '{"name":"mcp-server"}'; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge 10 ]; then
    echo "Failed to create API key after $ATTEMPTS attempts, exiting..."
    exit 1
  fi
  echo "Retrying in 3s ($ATTEMPTS/10)..."
  sleep 3
done

API_KEY_ENCODED=$(echo "$RESPONSE_BODY" | jq -r '.encoded')

if [ -z "$API_KEY_ENCODED" ] || [ "$API_KEY_ENCODED" = "null" ]; then
  echo "ERROR: Could not extract 'encoded' API key from response"
  exit 1
fi

mkdir -p /mcp-env

# ES_URL / ES_API_KEY / ES_SSL_SKIP_VERIFY are the config vars the
# elasticsearch-core-mcp-server binary reads (directly, or via this .env file
# loaded with dotenvy from its working directory). We skip TLS verification
# because the MCP server has no custom-CA option, only an on/off switch.
cat > /mcp-env/.env <<EOF
ES_URL=$ES_URL
ES_API_KEY=$API_KEY_ENCODED
ES_SSL_SKIP_VERIFY=true
EOF

# Also drop the raw key so post-start.sh / README curl examples can use it.
echo "$API_KEY_ENCODED" > /mcp-env/api-key

echo "=== MCP server API key created ==="
echo "$RESPONSE_BODY" | jq '{id, name}'
echo "Wrote /mcp-env/.env"
