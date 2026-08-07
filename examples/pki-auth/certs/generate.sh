#!/usr/bin/env bash
#
# Regenerates the CA and the client certificates this example authenticates with.
#
# The distinguished names are the whole point: ReadonlyREST reads the username out of CN and the groups
# out of OU, so these names and confs/readonlyrest.yml have to stay in step.
#
#   CN=svc-logstash, OU=ingest,  OU=Services  -> user svc-logstash, external group 'ingest'
#   CN=svc-dashboard,OU=query,   OU=Services  -> user svc-dashboard, external group 'query'
#   CN=jsmith,       OU=ingest,  OU=People    -> rejected: outside the provider's subject_dn_base
#
set -euo pipefail

cd "$(dirname "$0")"

DAYS=3650
BASE_DN="/DC=com/DC=example/DC=corp"

rm -f ./*.crt ./*.key ./*.csr ./*.srl

echo "==> certificate authority"
openssl req -x509 -newkey rsa:2048 -nodes -days "$DAYS" \
  -keyout pki-ca.key -out pki-ca.crt \
  -subj "${BASE_DN}/CN=Corp Issuing CA" 2>/dev/null

new_client() {
  local name="$1" subject="$2"
  openssl req -newkey rsa:2048 -nodes \
    -keyout "${name}.key" -out "${name}.csr" \
    -subj "${subject}" 2>/dev/null
  openssl x509 -req -in "${name}.csr" -days "$DAYS" \
    -CA pki-ca.crt -CAkey pki-ca.key -CAcreateserial \
    -out "${name}.crt" 2>/dev/null
  rm -f "${name}.csr"
  echo "    ${name}: $(openssl x509 -in "${name}.crt" -noout -subject | sed 's/^subject=//')"
}

echo "==> client certificates"
# openssl builds the DN in the order given, so OU=Services is written last and ends up
# rightmost - which is what subject_dn_base matches against
new_client "svc-logstash"  "${BASE_DN}/OU=Services/OU=ingest/CN=svc-logstash"
new_client "svc-dashboard" "${BASE_DN}/OU=Services/OU=query/CN=svc-dashboard"
new_client "jsmith"        "${BASE_DN}/OU=People/OU=ingest/CN=jsmith"

rm -f ./*.srl
echo
echo "==> done. Keep pki-ca.crt next to elasticsearch.yml so the node trusts these certificates."
