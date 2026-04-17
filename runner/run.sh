#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

if [ -z "${1:-}" ]; then
  selected=$(./utils/boot/select-example.sh ../examples) || exit 1
  set -- "$selected"
fi

# shellcheck source=utils/boot/prepare-example.sh
source "$(dirname "$0")/utils/boot/prepare-example.sh" "${1:-}"

if ! docker version &>/dev/null; then
  echo "No Docker found. Docker is required to run this Sandbox. See https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "No docker compose found. It seems you have to upgrade your Docker installation. See https://docs.docker.com/engine/install/"
  exit 2
fi

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

./utils/boot/print-example-info.sh "$EXAMPLE_DIR"
./utils/boot/collect-info-about-ror-es-kbn.sh
. ./utils/boot/check_license.sh "$(basename "$EXAMPLE_DIR")"

echo "Starting Elasticsearch and Kibana with installed ReadonlyREST plugins ..."

DOCKER_LOG=$(mktemp)
if ! docker compose "${COMPOSE_FILES[@]}" up -d --build --wait --remove-orphans --force-recreate > "$DOCKER_LOG" 2>&1; then
  cat "$DOCKER_LOG"
  rm -f "$DOCKER_LOG"
  exit 1
fi
rm -f "$DOCKER_LOG"

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
  echo -e "You can access ReadonlyREST Kibana here: https://localhost:15601"
  if command -v open &>/dev/null; then
    open https://localhost:15601
  elif command -v xdg-open &>/dev/null; then
    xdg-open https://localhost:15601
  fi
fi
