#!/bin/bash -e

source "$(dirname "$0")/collect-info-about-ror-es-kbn-with-hints-common.sh"

ROR_API_RESPONSE=''
STATUS_CODE=$(curl -s --max-time 5 -o /tmp/ror-api-response.txt -w "%{http_code}" https://api.beshu.tech/list_es_versions/20)

if [[ "$STATUS_CODE" -eq 200 ]]; then
  ROR_API_RESPONSE=$(cat /tmp/ror-api-response.txt)
  rm /tmp/ror-api-response.txt
else
  echo "ReadonlyREST API Error. Please try again later ..." 
  exit 128
fi

> .env
echo "-----------------"
determine_ror_es_dockerfile "$ROR_API_RESPONSE"
echo "-----------------"
source .env
determine_ror_kbn_dockerfile "$ROR_API_RESPONSE" "$ES_VERSION" "$ROR_ES_VERSION"
echo "-----------------"
