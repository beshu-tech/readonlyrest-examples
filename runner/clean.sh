#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

if [ -z "${1:-}" ] && [ ! -f .current-example ]; then
  echo "No running example found. Nothing to clean."
  echo "To clean a specific example, run: $0 <example-name>"
  exit 0
fi

# shellcheck source=utils/boot/resolve-example-dir.sh
source "$(dirname "$0")/utils/boot/resolve-example-dir.sh" "${1:-}"

docker compose "${COMPOSE_FILES[@]}" rm --stop --force
