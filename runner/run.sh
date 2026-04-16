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

BOOT_MSG="Starting Elasticsearch and Kibana with installed ReadonlyREST plugins"
printf '%s' "$BOOT_MSG"

DOCKER_LOG=$(mktemp)
docker compose "${COMPOSE_FILES[@]}" up -d --build --wait --remove-orphans --force-recreate > "$DOCKER_LOG" 2>&1 &
DOCKER_PID=$!

DOT_FRAMES=("." ".." "...")
_dot_i=0
while kill -0 "$DOCKER_PID" 2>/dev/null; do
  printf '\r%s%-3s' "$BOOT_MSG" "${DOT_FRAMES[$_dot_i]}"
  _dot_i=$(( (_dot_i + 1) % 3 ))
  sleep 0.5
done
printf '\n'

if ! wait "$DOCKER_PID"; then
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
  open https://localhost:15601
fi
