#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <example-name>"
  echo "Example: $0 basic"
  exit 1
fi

example_arg="$1"
if [[ "$example_arg" != */* ]]; then
  example_arg="../examples/$example_arg"
fi

export EXAMPLE_DIR
EXAMPLE_DIR="$(cd "$example_arg" && pwd)"

required_files=(
  "confs/elasticsearch.yml"
  "confs/readonlyrest.yml"
  "confs/kibana.yml"
)

for required in "${required_files[@]}"; do
  if [ ! -f "${EXAMPLE_DIR}/${required}" ]; then
    echo "ERROR: Required file not found in example directory: ${required}"
    exit 1
  fi
done

if [ -f "${EXAMPLE_DIR}/.env" ]; then
  cp "${EXAMPLE_DIR}/.env" .env
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

if ! docker version &>/dev/null; then
  echo "No Docker found. Docker is required to run this Sandbox. See https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "No docker compose found. It seems you have to upgrade your Docker installation. See https://docs.docker.com/engine/install/"
  exit 2
fi

COMPOSE_FILES=(-f docker-compose.yml)

if [ -f "${EXAMPLE_DIR}/docker-compose.override.yml" ]; then
  COMPOSE_FILES+=(-f "${EXAMPLE_DIR}/docker-compose.override.yml")
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

if ! docker compose "${COMPOSE_FILES[@]}" config > /dev/null; then
  echo "Cannot validate docker compose configuration. It seems you have to upgrade your Docker installation. See https://docs.docker.com/engine/install/"
  exit 3
fi

echo -e "

  _____                _  ____        _       _____  ______  _____ _______
 |  __ \              | |/ __ \      | |     |  __ \|  ____|/ ____|__   __|
 | |__) |___  __ _  __| | |  | |_ __ | |_   _| |__) | |__  | (___    | |
 |  _  // _ \/ _| |/ _| | |  | | '_ \| | | | |  _  /|  __|  \___ \   | |
 | | \ \  __/ (_| | (_| | |__| | | | | | |_| | | \ \| |____ ____) |  | |
 |_|  \_\___|\__,_|\__,_|\____/|_| |_|_|\__, |_|  \_\______|_____/   |_|
                                         __/ |
"

./utils/collect-info-about-ror-es-kbn.sh

# Call the extract helper using an explicit relative path (./../utils/...)
if output="$(./utils/extract_license_edition.sh "${ROR_ACTIVATION_KEY}" 2>&1)"; then
  rc=0
else
  rc=$?
fi

if [ $rc -ne 0 ]; then
  echo "ERROR: Failed to extract the ROR license edition (exit code: $rc)." >&2
  echo "$output" >&2
  exit $rc
elif [ -z "$output" ]; then
  echo "ERROR: Could not determine the ROR license edition (the extract_license_edition helper returned no result)." >&2
  exit 2
else
  export ROR_LICENSE_EDITION="$output"
  echo "Auto-detected ROR_LICENSE_EDITION=$ROR_LICENSE_EDITION"
fi

echo "Starting Elasticsearch and Kibana with installed ROR plugins ..."

docker compose "${COMPOSE_FILES[@]}" --profile "${ROR_LICENSE_EDITION}" up -d --build --wait --remove-orphans --force-recreate

docker compose "${COMPOSE_FILES[@]}" logs -f > ror-cluster.log 2>&1 &

echo -e "
***********************************************************************
***                                                                 ***
***          TIME TO PLAY!!!                                        ***
***                                                                 ***
***********************************************************************
"

if [ -f "${EXAMPLE_DIR}/scripts/post-start.sh" ]; then
  source "${EXAMPLE_DIR}/scripts/post-start.sh"
else
  echo -e "You can access ROR KBN here: https://localhost:15601"
  open https://localhost:15601
fi
