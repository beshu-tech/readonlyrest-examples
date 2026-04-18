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

echo -e ""

./utils/boot/run-with-spinner.sh \
  "Starting Elasticsearch and Kibana with installed ReadonlyREST plugins" \
  docker compose "${COMPOSE_FILES[@]}" up -d --build --wait --remove-orphans --force-recreate

# shellcheck source=utils/boot/post-start.sh
. ./utils/boot/post-start.sh
