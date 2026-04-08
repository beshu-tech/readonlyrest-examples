#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

# shellcheck source=utils/prepare-example.sh
source "$(dirname "$0")/utils/prepare-example.sh" "${1:-}"

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

./utils/collect-info-about-ror-es-kbn.sh
. ./utils/check_license.sh "$(basename "$EXAMPLE_DIR")"

echo "Starting Elasticsearch and Kibana with installed ROR plugins ..."

docker compose "${COMPOSE_FILES[@]}" up -d --build --wait --remove-orphans --force-recreate

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
