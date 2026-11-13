#!/bin/bash
# Walks through personal API keys against the running example.
# Requires: curl and docker on the host. Start the example first: ./run.sh personal-api-keys

set -uo pipefail

ES="${ES_URL:-https://localhost:19200}"
LDAP_CONTAINER="ror-ldap"
LDAP_GROUP_CHANGE_WAIT=8 # seconds; longer than cache_ttl in confs/readonlyrest.yml

STEP=0
FAILURES=0

step() {
  STEP=$((STEP + 1))
  echo
  echo "=== $STEP. $1"
}

# call <expected status> <auth: user:pass | apikey:<encoded>> <method> <path> [body]
call() {
  local expected="$1" auth="$2" method="$3" path="$4" body="${5:-}"
  local auth_args
  if [[ "$auth" == apikey:* ]]; then
    auth_args=(-H "Authorization: ApiKey ${auth#apikey:}")
  else
    auth_args=(-u "$auth")
  fi
  local args=(-sk -X "$method" "${auth_args[@]}" -w '\n%{http_code}' "$ES$path")
  if [[ -n "$body" ]]; then
    args+=(-H 'Content-Type: application/json' -d "$body")
  fi
  local response status
  response=$(curl "${args[@]}")
  status=$(tail -n1 <<< "$response")
  LAST_BODY=$(sed '$d' <<< "$response")
  if [[ "$status" == "$expected" ]]; then
    echo "  OK   $method $path -> $status"
  else
    echo "  FAIL $method $path -> $status (expected $expected)"
    echo "       $LAST_BODY"
    FAILURES=$((FAILURES + 1))
  fi
}

json_field() {
  sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" <<< "$LAST_BODY"
}

ldap_group_member() {
  local change="$1" user="$2" group="$3"
  docker exec -i "$LDAP_CONTAINER" ldapmodify -x -H ldap://localhost -D cn=admin,dc=example,dc=com -w admin > /dev/null <<EOF
dn: cn=$group,ou=Groups,dc=example,dc=com
changetype: modify
$change: uniqueMember
uniqueMember: uid=$user,ou=People,dc=example,dc=com
EOF
}

step "alice (kibana-users) creates an API key. She is its owner."
call 200 alice:alice POST /_security/api_key '{"name":"alice-key","metadata":{"team":"sales"}}'
ALICE_KEY_ID=$(json_field id)
ALICE_KEY=$(json_field encoded)

step "bob (kibana-users) creates an API key"
call 200 bob:bob POST /_security/api_key '{"name":"bob-key"}'
BOB_KEY_ID=$(json_field id)
BOB_KEY=$(json_field encoded)

step "carol (in no Kibana group) cannot create an API key"
call 403 carol:carol POST /_security/api_key '{"name":"carol-key"}'

step "dave (kibana-viewers, access ro) can list own API keys, but cannot create one"
call 200 dave:dave GET /_security/api_key
call 403 dave:dave POST /_security/api_key '{"name":"dave-key"}'

step "Each key runs as its owner, with the current LDAP groups of the owner"
echo "  (ROR answers 404 for an index that the user cannot read, so the index stays hidden)"
call 200 "apikey:$ALICE_KEY" GET /logstash-sales-2026/_search
call 404 "apikey:$ALICE_KEY" GET /logstash-finance-2026/_search
call 200 "apikey:$BOB_KEY" GET /logstash-finance-2026/_search
call 404 "apikey:$BOB_KEY" GET /logstash-sales-2026/_search

step "alice updates the metadata of her key. The key still runs as alice."
call 200 alice:alice PUT "/_security/api_key/$ALICE_KEY_ID" '{"metadata":{"team":"sales","env":"prod"}}'
call 200 "apikey:$ALICE_KEY" GET /logstash-sales-2026/_search

step "A request with an API key cannot create another API key"
call 403 "apikey:$ALICE_KEY" POST /_security/api_key '{"name":"key-from-key"}'

step "bob sees only his own keys, and cannot revoke the key of alice"
call 200 bob:bob GET /_security/api_key
if grep -q "$ALICE_KEY_ID" <<< "$LAST_BODY"; then
  echo "  FAIL the response holds the key of alice"
  FAILURES=$((FAILURES + 1))
else
  echo "  OK   the response does not hold the key of alice"
fi
call 403 bob:bob DELETE /_security/api_key "{\"ids\":[\"$ALICE_KEY_ID\"]}"
call 403 bob:bob DELETE /_security/api_key '{"name":"alice-key"}'
call 403 bob:bob DELETE /_security/api_key "{\"ids\":[\"$ALICE_KEY_ID\"],\"owner\":true}"

step "Remove alice from sales-readers in LDAP. Her key loses access to the sales index."
ldap_group_member delete alice sales-readers
sleep "$LDAP_GROUP_CHANGE_WAIT"
call 403 "apikey:$ALICE_KEY" GET /logstash-sales-2026/_search

step "Add alice back to sales-readers. Her key gets access again."
ldap_group_member add alice sales-readers
sleep "$LDAP_GROUP_CHANGE_WAIT"
call 200 "apikey:$ALICE_KEY" GET /logstash-sales-2026/_search

step "erin (kibana-admins, access admin) sees all keys and revokes the key of bob"
call 200 erin:erin GET /_security/api_key
grep -q "$ALICE_KEY_ID" <<< "$LAST_BODY" && grep -q "$BOB_KEY_ID" <<< "$LAST_BODY" &&
  echo "  OK   the response holds the keys of alice and bob" ||
  { echo "  FAIL the response does not hold both keys"; FAILURES=$((FAILURES + 1)); }
call 200 erin:erin DELETE /_security/api_key "{\"ids\":[\"$BOB_KEY_ID\"]}"

step "A revoked key stops working at once"
call 403 "apikey:$BOB_KEY" GET /logstash-finance-2026/_search

step "alice revokes her own key"
call 200 alice:alice DELETE /_security/api_key "{\"ids\":[\"$ALICE_KEY_ID\"],\"owner\":true}"
call 403 "apikey:$ALICE_KEY" GET /logstash-sales-2026/_search

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All steps passed."
else
  echo "$FAILURES check(s) failed."
  exit 1
fi
