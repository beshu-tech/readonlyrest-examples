#!/bin/bash -e

echo "Preparing Elasticsearch & Kibana with ROR environment ..."

if [[ -e ".env" ]] && grep -q '^[A-Z_][A-Z0-9_]*=' ".env"; then
  echo "Found .env - running in non-interactive mode ..."
  source .env

  missing=()
  if [[ -z "${ES_VERSION:-}" ]]; then missing+=("ES_VERSION"); fi
  if [[ -z "${ROR_ES_PLUGIN_SOURCE:-}" ]]; then missing+=("ROR_ES_PLUGIN_SOURCE"); fi
  if [[ -z "${KBN_VERSION:-}" ]]; then missing+=("KBN_VERSION"); fi
  if [[ -z "${ROR_KBN_PLUGIN_SOURCE:-}" ]]; then missing+=("ROR_KBN_PLUGIN_SOURCE"); fi

  if [[ -n "${ROR_ES_PLUGIN_SOURCE:-}" ]]; then
    if [[ "$ROR_ES_PLUGIN_SOURCE" == "LOCAL_FILE" ]]; then
      if [[ -z "${ROR_ES_FILE:-}" ]]; then missing+=("ROR_ES_FILE"); fi
    elif [[ "$ROR_ES_PLUGIN_SOURCE" == "API" ]]; then
      if [[ -z "${ROR_ES_VERSION:-}" ]]; then missing+=("ROR_ES_VERSION"); fi
    fi
  fi

  if [[ -n "${ROR_KBN_PLUGIN_SOURCE:-}" ]]; then
    if [[ "$ROR_KBN_PLUGIN_SOURCE" == "LOCAL_FILE" ]]; then
      if [[ -z "${ROR_KBN_FILE:-}" ]]; then missing+=("ROR_KBN_FILE"); fi
    elif [[ "$ROR_KBN_PLUGIN_SOURCE" == "API" ]]; then
      if [[ -z "${ROR_KBN_VERSION:-}" ]]; then missing+=("ROR_KBN_VERSION"); fi
    fi
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: .env is missing required variables: ${missing[*]}" >&2
    exit 1
  fi

  if [[ "$ROR_ES_PLUGIN_SOURCE" == "LOCAL_FILE" ]]; then
    es_ror_info="FILE: $ROR_ES_FILE"
  else
    es_ror_info="API: ROR ES $ROR_ES_VERSION"
  fi

  if [[ "$ROR_KBN_PLUGIN_SOURCE" == "LOCAL_FILE" ]]; then
    kbn_ror_info="FILE: $ROR_KBN_FILE"
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
