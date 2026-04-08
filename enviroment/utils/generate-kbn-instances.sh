# This file must be sourced, not executed directly.
# Generates Kibana service definitions from the template for all instances.
# Requires: EXAMPLE_DIR, KBN_INSTANCES, COMPOSE_FILES (array)
# Modifies: COMPOSE_FILES (appends the generated file)
# Must be sourced, not executed.

GENERATED_INSTANCES_FILE="$(mktemp /tmp/ror-kbn-instances-XXXXXX)"
echo "services:" > "$GENERATED_INSTANCES_FILE"
_ENVIROMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_KIBANA_YML="${EXAMPLE_DIR}/confs/kibana.yml"
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
    -e "s|@@ENVIROMENT_DIR@@|${_ENVIROMENT_DIR}|g" \
    "${_ENVIROMENT_DIR}/templates/kbn-instance.yml.tpl" >> "$GENERATED_INSTANCES_FILE"
done
COMPOSE_FILES+=(-f "$GENERATED_INSTANCES_FILE")
unset _ENVIROMENT_DIR _KIBANA_YML _i _KBN_NAME _PORT
