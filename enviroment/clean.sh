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

# shellcheck source=utils/setup-compose-files.sh
source "$(dirname "$0")/utils/setup-compose-files.sh"

docker compose "${COMPOSE_FILES[@]}" --profile ENT --profile PRO --profile FREE rm --stop --force
