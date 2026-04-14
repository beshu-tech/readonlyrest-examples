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

if [ ! -d "$example_arg" ]; then
  echo "ERROR: Example '${1}' not found."
  echo ""
  echo "Available examples:"
  for dir in ../examples/*/; do
    [ -d "$dir" ] && echo "  - $(basename "$dir")"
  done
  # Suggest close matches (substring)
  matches=()
  for dir in ../examples/*/; do
    name="$(basename "$dir")"
    if [[ "$name" == *"${1}"* || "${1}" == *"$name"* ]]; then
      matches+=("$name")
    fi
  done
  if [ ${#matches[@]} -gt 0 ]; then
    echo ""
    echo "Did you mean:"
    for m in "${matches[@]}"; do
      echo "  $0 $m"
    done
  fi
  exit 1
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
fi

if ! docker version &>/dev/null; then
  echo "No Docker found. Docker is required to run this Sandbox. See https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "No docker compose found. It seems you have to upgrade your Docker installation. See https://docs.docker.com/engine/install/"
  exit 2
fi

if ! docker compose config > /dev/null; then
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

./utils/boot/print-example-info.sh "$example_arg"
./utils/boot/collect-info-about-ror-es-kbn.sh
. ./utils/boot/check_license.sh "$example_arg"

echo "Starting Elasticsearch and Kibana with installed ReadonlyREST plugins ..."

DOCKER_LOG=$(mktemp)
if ! docker compose up -d --build --wait --remove-orphans --force-recreate > "$DOCKER_LOG" 2>&1; then
  cat "$DOCKER_LOG"
  rm -f "$DOCKER_LOG"
  exit 1
fi
rm -f "$DOCKER_LOG"

docker compose logs -f > ror-cluster.log 2>&1 &

echo -e "
***********************************************************************
***                                                                 ***
***          TIME TO PLAY!!!                                        ***
***                                                                 ***
***********************************************************************
"

echo -e "You can access Kibana with ReadonlyREST here: https://localhost:15601"
open https://localhost:15601
