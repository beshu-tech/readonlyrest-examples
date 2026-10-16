#!/bin/bash -ex

# `bash init.sh` (how cluster-initializer invokes this) ignores the shebang
# flags, so set them here.
set -exo pipefail

source /usr/local/lib/ror-utils.sh

# "logs-app-2026" (matching Elasticsearch's built-in "logs-*-*" index template)
# would fail with "matches a data-stream-only template" — a single hyphen avoids it.
# "analyst" reads this one; "hr" cannot see it.
createIndex "logs-2026" && generate_log_documents 50 | putDocument "logs-2026"

# The index both MCP users share, so the two agents have common ground.
createIndex "orders-2026"
putDocument "orders-2026" '{"order_id":"ORD-1001","customer":"Acme Corp","amount":4520.00,"status":"shipped","@timestamp":"2026-09-01T10:15:00Z"}'
putDocument "orders-2026" '{"order_id":"ORD-1002","customer":"Globex","amount":980.50,"status":"pending","@timestamp":"2026-09-05T14:32:00Z"}'
putDocument "orders-2026" '{"order_id":"ORD-1003","customer":"Initech","amount":12300.75,"status":"shipped","@timestamp":"2026-09-10T09:05:00Z"}'

# "hr" reads this one, "analyst" cannot see it at all - neither through
# list_indices nor through a direct search.
createIndex "hr-salaries-2026"
putDocument "hr-salaries-2026" '{"employee":"Alice Smith","department":"Engineering","salary":128000,"@timestamp":"2026-01-01T00:00:00Z"}'
putDocument "hr-salaries-2026" '{"employee":"Bob Jones","department":"Sales","salary":95000,"@timestamp":"2026-01-01T00:00:00Z"}'
