#!/bin/bash -ex

POLICY_ID="elastic-policy"
FLEET_ENROLLMENT_TOKEN=$(curl -k -s \
  -u kibana:kibana \
  https://kbn-ror:5601/api/fleet/enrollment_api_keys | \
  jq -r '.items[] | select(any(.; .policy_id == "'$POLICY_ID'")) | .api_key')

if [[ -z "$FLEET_ENROLLMENT_TOKEN" ]]; then
  echo "Failed to retrieve enrollment token for policy_id: $POLICY_ID" >&2
  exit 1
fi

export FLEET_ENROLLMENT_TOKEN

/usr/local/bin/docker-entrypoint
