#!/bin/bash -ex

set -o pipefail

source /usr/local/lib/ror-utils.sh

# Operational log indices — accessed by local users (alice:alice / bob:bob)
createIndex "alice-logs"
echo '{"user":"alice","message":"Alice app event - login","level":"INFO","service":"auth","@timestamp":"2024-01-15T10:23:45Z"}' \
  | putDocument "alice-logs"

createIndex "bob-logs"
echo '{"user":"bob","message":"Bob app event - login","level":"INFO","service":"auth","@timestamp":"2024-01-15T10:24:12Z"}' \
  | putDocument "bob-logs"

# AI/MCP report indices — accessed exclusively via API keys by the AI/MCP service
createIndex "alice-reports"
echo '{"user":"alice","title":"Q1 summary","content":"Alice Q1 performance report","category":"reports","@timestamp":"2024-01-15T08:00:00Z"}' \
  | putDocument "alice-reports"

createIndex "bob-reports"
echo '{"user":"bob","title":"Q1 summary","content":"Bob Q1 performance report","category":"reports","@timestamp":"2024-01-15T08:05:00Z"}' \
  | putDocument "bob-reports"

# Create the readonlyrest_audit-* data view in Kibana so audit events are
# immediately browsable in Discover without any manual setup.
# Kibana starts in parallel with the initializer, so we wait for it first.
echo "Waiting for Kibana..."
until curl -fksS --connect-timeout 3 --max-time 5 \
    -u admin:admin https://kbn-ror:5601/api/features >/dev/null 2>&1; do
  sleep 5
done

curl -ksS -u admin:admin \
  -X POST "https://kbn-ror:5601/api/data_views/data_view" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{"data_view":{"title":"readonlyrest_audit-*","timeFieldName":"@timestamp"}}' \
  || true
