#!/bin/bash -ex
#
# Fetch the Fleet enrollment token for elastic-policy and pass it to the
# standard elastic-agent docker-entrypoint via FLEET_ENROLLMENT_TOKEN.
#
# The fleet-initializer creates the elastic-policy and its enrollment token
# before this container starts (see depends_on in docker-compose.override.yml).
# We cannot bake the token into the image because it is generated at runtime
# by the Fleet Server.

POLICY_ID="elastic-policy"
FLEET_ENROLLMENT_TOKEN=$(curl -s --cacert /certs/ca.crt \
  -u kibana:kibana \
  https://kbn-ror:5601/api/fleet/enrollment_api_keys | \
  jq -r '.items[] | select(any(.; .policy_id == "'$POLICY_ID'")) | .api_key')

if [[ -z "$FLEET_ENROLLMENT_TOKEN" ]]; then
  echo "Failed to retrieve enrollment token for policy_id: $POLICY_ID" >&2
  exit 1
fi

export FLEET_ENROLLMENT_TOKEN

/usr/local/bin/docker-entrypoint
