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
  GENERATED_INSTANCES_FILE="$(mktemp /tmp/ror-kbn-instances-XXXXXX)"
  echo "services:" > "$GENERATED_INSTANCES_FILE"
  ENVIROMENT_DIR="$(pwd)"
  KIBANA_YML="${EXAMPLE_DIR}/confs/kibana.yml"
  for i in $(seq 1 "${KBN_INSTANCES}"); do
    if [ "$i" -eq 1 ]; then
      KBN_NAME="kbn-ror"
      PORT=15601
    else
      KBN_NAME="kbn-ror-${i}"
      PORT=$((15600 + i))
    fi
    sed \
      -e "s|@@KBN_INSTANCE_NAME@@|${KBN_NAME}|g" \
      -e "s|@@KBN_INSTANCE_PORT@@|${PORT}|g" \
      -e "s|@@KBN_INSTANCE_KIBANA_YML@@|${KIBANA_YML}|g" \
      -e "s|@@ENVIROMENT_DIR@@|${ENVIROMENT_DIR}|g" \
      templates/kbn-instance.yml.tpl >> "$GENERATED_INSTANCES_FILE"
  done
  COMPOSE_FILES+=(-f "$GENERATED_INSTANCES_FILE")
fi

docker compose "${COMPOSE_FILES[@]}" --profile ENT --profile PRO --profile FREE rm --stop --force
