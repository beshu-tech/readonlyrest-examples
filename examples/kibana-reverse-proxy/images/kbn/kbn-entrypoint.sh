#!/bin/bash
set -eu
if [ -n "${BASH_VERSION:-}" ]; then
  set -o pipefail
fi

# Normalize various truthy/falsey values to "true" or "false"
_normalize_bool() {
  local v="${1:-}"
  v="$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')"
  case "$v" in
    1|true|yes|y) echo "true" ;;
    0|false|no|n) echo "false" ;;
    *) echo "" ;;
  esac
}

# Replace or prepend a simple top-level YAML key (dotted keys allowed).
# Avoids sed -i which breaks on Docker bind-mounted files (creates new inode).
_upsert_yaml_key() {
  local cfg_file="$1"
  local key="$2"
  local val="$3"
  [ -f "$cfg_file" ] || return 0
  local key_esc
  key_esc="$(printf '%s' "$key" | sed 's/\./\\./g')"
  if grep -qE "^${key_esc}:" "$cfg_file"; then
    local content
    content="$(sed "s/^${key_esc}:.*/${key}: ${val}/" "$cfg_file")"
    printf '%s\n' "$content" > "$cfg_file"
  else
    local content
    content="$(cat "$cfg_file")"
    printf '%s: %s\n%s\n' "${key}" "${val}" "$content" > "$cfg_file"
  fi
}

cfg="/usr/share/kibana/config/kibana.yml"

# Inject REWRITE_BASE_PATH_BY_KIBANA if provided
if [ -n "${REWRITE_BASE_PATH_BY_KIBANA:-}" ]; then
  rbp="$(_normalize_bool "${REWRITE_BASE_PATH_BY_KIBANA}")"
  if [ -n "$rbp" ]; then
    _upsert_yaml_key "$cfg" "server.rewriteBasePath" "$rbp"
    echo "INFO: Applied server.rewriteBasePath=${rbp} to ${cfg}"
  else
    echo "WARN: REWRITE_BASE_PATH_BY_KIBANA value not recognized: ${REWRITE_BASE_PATH_BY_KIBANA}"
  fi
fi

exec /usr/local/bin/kibana-docker
