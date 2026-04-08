#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

COMPOSE_FILES=(-f docker-compose.yml)

if [ -n "${1:-}" ]; then
  example_arg="$1"
  if [[ "$example_arg" != */* ]]; then
    example_arg="../examples/$example_arg"
  fi

  EXAMPLE_DIR="$(cd "$example_arg" && pwd)"

  if [ -f "${EXAMPLE_DIR}/docker-compose.override.yml" ]; then
    COMPOSE_FILES+=(-f "${EXAMPLE_DIR}/docker-compose.override.yml")
  fi

  if [ -f "${EXAMPLE_DIR}/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "${EXAMPLE_DIR}/.env"
    set +a
  fi

  KBN_INSTANCES=${KBN_INSTANCES:-1}
  if [ "${KBN_INSTANCES}" -gt 1 ]; then
    GENERATED_INSTANCES_FILE="$(mktemp /tmp/ror-kbn-instances-XXXXXX)"
    echo "services:" > "$GENERATED_INSTANCES_FILE"
    ENVIROMENT_DIR="$(pwd)"
    for i in $(seq 2 "${KBN_INSTANCES}"); do
      PORT=$((15600 + i))
      KIBANA_YML="${EXAMPLE_DIR}/confs/kibana-${i}.yml"
      sed \
        -e "s|@@KBN_INSTANCE_NAME@@|kbn-ror-${i}|g" \
        -e "s|@@KBN_INSTANCE_PORT@@|${PORT}|g" \
        -e "s|@@KBN_INSTANCE_KIBANA_YML@@|${KIBANA_YML}|g" \
        -e "s|@@ENVIROMENT_DIR@@|${ENVIROMENT_DIR}|g" \
        templates/kbn-instance.yml.tpl >> "$GENERATED_INSTANCES_FILE"
    done
    COMPOSE_FILES+=(-f "$GENERATED_INSTANCES_FILE")
  fi
fi

docker compose "${COMPOSE_FILES[@]}" --profile ENT --profile PRO --profile FREE rm --stop --force
