# This file must be sourced, not executed directly.
# Generates Kibana service definitions from the template for all instances.
# Requires: EXAMPLE_DIR, KBN_INSTANCES, COMPOSE_FILES (array)
# Modifies: COMPOSE_FILES (appends the generated file)

_GENERATED_INSTANCES_FILE="$(mktemp "${TMPDIR:-/tmp}/ror-kbn-instances-XXXXXX")" || return 1
echo "services:" > "$_GENERATED_INSTANCES_FILE"

_ENVIRONMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_KIBANA_YML="${EXAMPLE_DIR}/confs/kibana.yml"
_KIBANA_EXTRA="${EXAMPLE_DIR}/scripts/kibana-conf-extra-settings.sh"

if [ -f "$_KIBANA_EXTRA" ]; then
  _tmp_base="$(mktemp "${TMPDIR:-/tmp}/ror-kbn-kibana-yml-XXXXXX")" || return 1
  _KIBANA_YML_TMP="${_tmp_base}.yml"
  mv -- "$_tmp_base" "$_KIBANA_YML_TMP" || return 1

  {
    cat "$_KIBANA_YML"
    bash "$_KIBANA_EXTRA"
  } > "$_KIBANA_YML_TMP" || return 1

  _KIBANA_YML="$_KIBANA_YML_TMP"
fi

for _i in $(seq 1 "${KBN_INSTANCES}"); do
  if [ "$_i" -eq 1 ]; then
    _KBN_NAME="kbn-ror"
    _PORT=15601
  else
    _KBN_NAME="kbn-ror-${_i}"
    _PORT=$((15600 + _i))
  fi

  sed \
    -e "s|@@KBN_INSTANCE_NAME@@|${_KBN_NAME}|g" \
    -e "s|@@KBN_INSTANCE_PORT@@|${_PORT}|g" \
    -e "s|@@KBN_INSTANCE_KIBANA_YML@@|${_KIBANA_YML}|g" \
    -e "s|@@ENVIRONMENT_DIR@@|${_ENVIRONMENT_DIR}|g" \
    "${_ENVIRONMENT_DIR}/templates/kbn-instance.yml.tpl" >> "$_GENERATED_INSTANCES_FILE" || return 1
done

COMPOSE_FILES+=(-f "$_GENERATED_INSTANCES_FILE")

unset _GENERATED_INSTANCES_FILE _ENVIRONMENT_DIR _KIBANA_YML _KIBANA_EXTRA _tmp_base _KIBANA_YML_TMP _i _KBN_NAME _PORT