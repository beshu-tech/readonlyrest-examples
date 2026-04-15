#!/bin/bash -x

KIBANA_URL="https://kbn-ror:5601"

check_curl() {
  local description="$1"
  shift

  echo "Executing: $description"

  local http_code
  local response
  response=$(curl -w "\n%{http_code}" "$@")
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$d')

  echo "Response body: $body"
  echo "HTTP Status: $http_code"

  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "OK: $description (HTTP $http_code)"
    return 0
  else
    echo "FAILED: $description (HTTP $http_code)"
    return 1
  fi
}

while true; do
  if curl -f -i --cacert /certs/ca.crt -u kibana:kibana "$KIBANA_URL/api/features" | grep -q 'content-type: application/json'; then

    set -x

    echo "=== Checking Kibana Info ==="
    curl -s -u "kibana:kibana" --cacert /certs/ca.crt "$KIBANA_URL/api/status" | jq '.version, .status'

    KBN_MAJOR_VERSION=$(curl -s -u "kibana:kibana" --cacert /certs/ca.crt "$KIBANA_URL/api/status" | jq -r '.version.number' | cut -d. -f1)
    echo "Detected Kibana major version: $KBN_MAJOR_VERSION"

    echo "=== Current Fleet settings ==="
    curl -s -u "kibana:kibana" --cacert /certs/ca.crt "$KIBANA_URL/api/fleet/settings" | jq .

    if ! check_curl "Create Elastic Agent Policy" \
      -s -u "kibana:kibana" --cacert /certs/ca.crt \
      -XPOST -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
      "$KIBANA_URL/api/fleet/agent_policies" \
      -d '{"id":"elastic-policy","name":"Elastic-Policy","namespace":"default","monitoring_enabled":["logs","metrics"]}'; then
      echo "Failed to create agent policy, exiting..."
      exit 1
    fi

    if ! check_curl "Create System Package Policy" \
      -s -u "kibana:kibana" --cacert /certs/ca.crt \
      -XPOST -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
      "$KIBANA_URL/api/fleet/package_policies" \
      -d '{"name":"Elastic-System-package","namespace":"default","policy_id":"elastic-policy","package":{"name":"system","version":"1.54.0"}}'; then
      echo "Failed to create system package policy, exiting..."
      exit 1
    fi

    echo "=== Detecting APM package version ==="
    APM_VERSION=$(curl -s -u "kibana:kibana" --cacert /certs/ca.crt \
      "$KIBANA_URL/api/fleet/epm/packages/apm" | jq -r '.item.version')

    if [ -z "$APM_VERSION" ] || [ "$APM_VERSION" = "null" ]; then
      echo "ERROR: Could not detect APM package version"
      exit 1
    fi

    echo "Detected APM package version: $APM_VERSION"

    if ! check_curl "Create APM Package Policy" \
      -s -u "kibana:kibana" --cacert /certs/ca.crt \
      -XPOST -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
      "$KIBANA_URL/api/fleet/package_policies" \
      -d "{\"name\":\"apm2\",\"namespace\":\"default\",\"policy_id\":\"elastic-policy\",\"package\":{\"name\":\"apm\",\"version\":\"$APM_VERSION\"},\"inputs\":[{\"type\":\"apm\",\"enabled\":true,\"streams\":[],\"policy_template\":\"apmserver\",\"vars\":{\"host\":{\"value\":\"0.0.0.0:8200\",\"type\":\"text\"},\"url\":{\"value\":\"https://agent1:8200\",\"type\":\"text\"},\"tls_enabled\":{\"value\":true,\"type\":\"bool\"},\"tls_certificate\":{\"value\":\"/certs/agent1.crt\",\"type\":\"text\"},\"tls_key\":{\"value\":\"/certs/agent1.key\",\"type\":\"text\"}}}]}"; then
      echo "Failed to create APM package policy, exiting..."
      exit 1
    fi

    if [ "$KBN_MAJOR_VERSION" -ge 9 ]; then
      EXISTING_HOST_ID=$(curl -s -u "kibana:kibana" --cacert /certs/ca.crt \
        "$KIBANA_URL/api/fleet/fleet_server_hosts" | jq -r '.items[0].id // empty')

      if [ -n "$EXISTING_HOST_ID" ]; then
        if ! check_curl "Update Fleet Server Host" \
          -s -u "kibana:kibana" --cacert /certs/ca.crt \
          -XPUT -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
          "$KIBANA_URL/api/fleet/fleet_server_hosts/$EXISTING_HOST_ID" \
          -d '{"host_urls":["https://fleet-server:8220"],"is_default":true}'; then
          echo "Failed to update fleet server host, exiting..."
          exit 1
        fi
      else
        if ! check_curl "Create Fleet Server Host" \
          -s -u "kibana:kibana" --cacert /certs/ca.crt \
          -XPOST -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
          "$KIBANA_URL/api/fleet/fleet_server_hosts" \
          -d '{"name":"Default","host_urls":["https://fleet-server:8220"],"is_default":true}'; then
          echo "Failed to create fleet server host, exiting..."
          exit 1
        fi
      fi
    else
      if ! check_curl "Update Fleet Settings" \
        -s -u "kibana:kibana" --cacert /certs/ca.crt \
        -XPUT -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
        "$KIBANA_URL/api/fleet/settings" \
        -d '{"fleet_server_hosts": ["https://fleet-server:8220"]}'; then
        echo "Failed to update fleet settings, exiting..."
        exit 1
      fi
    fi

    if ! check_curl "Update Fleet Output" \
      -s -u "kibana:kibana" --cacert /certs/ca.crt \
      -XPUT -H "kbn-xsrf: kibana" -H "Content-type: application/json" \
      "$KIBANA_URL/api/fleet/outputs/fleet-default-output" \
      -d '{"hosts":["https://es-ror:9200"],"config_yaml":"ssl.verification_mode: certificate\nssl.certificate_authorities: [\"/certs/ca.crt\"]"}'; then
      echo "Failed to update fleet output, exiting..."
      exit 1
    fi

    echo "=== Fleet settings after changes ==="
    curl -s -u "kibana:kibana" --cacert /certs/ca.crt "$KIBANA_URL/api/fleet/settings" | jq .

    echo "=== Agent Policy Details ==="
    curl -s -u "kibana:kibana" --cacert /certs/ca.crt "$KIBANA_URL/api/fleet/agent_policies/elastic-policy" | jq .

    echo "=== Enrollment Tokens ==="
    curl -s -u "kibana:kibana" --cacert /certs/ca.crt "$KIBANA_URL/api/fleet/enrollment_api_keys" | jq '.items[] | select(.policy_id == "elastic-policy")'

    echo "All fleet configuration completed successfully!"
    break
  else
    echo "Waiting for Kibana to be ready..."
    sleep 5
  fi
done
