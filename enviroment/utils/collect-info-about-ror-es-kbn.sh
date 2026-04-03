#!/bin/bash -e

echo "Preparing Elasticsearch & Kibana with ROR environment ..."

if [[ -e ".env-showcase" ]] && grep -q '^[A-Z_][A-Z0-9_]*=' ".env-showcase"; then
  echo "Found .env-showcase - running in non-interactive mode ..."
  source .env-showcase

  missing=()
  if [[ -z "${ES_VERSION:-}" ]]; then missing+=("ES_VERSION"); fi
  if [[ -z "${ES_DOCKERFILE:-}" ]]; then missing+=("ES_DOCKERFILE"); fi
  if [[ -z "${KBN_VERSION:-}" ]]; then missing+=("KBN_VERSION"); fi
  if [[ -z "${KBN_DOCKERFILE:-}" ]]; then missing+=("KBN_DOCKERFILE"); fi

  if [[ -n "${ES_DOCKERFILE:-}" ]]; then
    if [[ "$ES_DOCKERFILE" == *"from-file"* ]]; then
      if [[ -z "${ES_ROR_FILE:-}" ]]; then missing+=("ES_ROR_FILE"); fi
    elif [[ "$ES_DOCKERFILE" == *"from-api"* ]]; then
      if [[ -z "${ROR_ES_VERSION:-}" ]]; then missing+=("ROR_ES_VERSION"); fi
    fi
  fi

  if [[ -n "${KBN_DOCKERFILE:-}" ]]; then
    if [[ "$KBN_DOCKERFILE" == *"from-file"* ]]; then
      if [[ -z "${KBN_ROR_FILE:-}" ]]; then missing+=("KBN_ROR_FILE"); fi
    elif [[ "$KBN_DOCKERFILE" == *"from-api"* ]]; then
      if [[ -z "${ROR_KBN_VERSION:-}" ]]; then missing+=("ROR_KBN_VERSION"); fi
    fi
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: .env-showcase is missing required variables: ${missing[*]}" >&2
    exit 1
  fi

  cp .env-showcase .env

  if [[ "$ES_DOCKERFILE" == *"from-file"* ]]; then
    es_ror_info="FILE: $ES_ROR_FILE"
  else
    es_ror_info="API: ROR ES $ROR_ES_VERSION"
  fi

  if [[ "$KBN_DOCKERFILE" == *"from-file"* ]]; then
    kbn_ror_info="FILE: $KBN_ROR_FILE"
  else
    kbn_ror_info="API: ROR KBN $ROR_KBN_VERSION"
  fi

  echo "  Elasticsearch $ES_VERSION ($es_ror_info)"
  echo "  Kibana        $KBN_VERSION ($kbn_ror_info)"

  exit 0
fi

if ! command -v jq > /dev/null; then
  $(dirname "$0")/collect-info-about-ror-es-kbn-without-hints.sh
else
  $(dirname "$0")/collect-info-about-ror-es-kbn-with-hints.sh || {
    if [[ $? -eq 28 || $? -eq 128 ]]; then
      $(dirname "$0")/collect-info-about-ror-es-kbn-without-hints.sh
    else
      exit $?
    fi
  }
fi
