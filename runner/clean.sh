#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

example_name="${1:-}"
if [ -z "$example_name" ]; then
  if [ -f .current-example ]; then
    example_name="$(cat .current-example)"
    echo "No example specified, using last run: $example_name"
  else
    echo "No running example found. Nothing to clean."
    echo "To clean a specific example, run: $0 <example-name>"
    exit 0
  fi
fi

example_arg="$example_name"
if [[ "$example_arg" != */* ]]; then
  example_arg="../examples/$example_arg"
fi

export EXAMPLE_DIR
EXAMPLE_DIR="$(cd "$example_arg" && pwd)"

# shellcheck source=utils/setup-compose-files.sh
source "$(dirname "$0")/utils/setup-compose-files.sh"

docker compose "${COMPOSE_FILES[@]}" rm --stop --force
