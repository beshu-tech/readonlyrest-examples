# This file must be sourced, not executed directly.
# Usage: source prepare-example.sh [example-name]
# Requires: called from the runner/ directory (cd "$(dirname "$0")" first)
# Sets: EXAMPLE_DIR, COMPOSE_FILES (via resolve-example-dir.sh -> setup-compose-files.sh)
# Side effects: writes .current-example, copies example's .env to runner/

# shellcheck source=resolve-example-dir.sh
source "$(dirname "${BASH_SOURCE[0]}")/resolve-example-dir.sh" "${1:-}"

echo "$(basename "$EXAMPLE_DIR")" > .current-example

_required_files=(
  "confs/elasticsearch.yml"
  "confs/readonlyrest.yml"
  "confs/kibana.yml"
)

for _required in "${_required_files[@]}"; do
  if [ ! -f "${EXAMPLE_DIR}/${_required}" ]; then
    echo "ERROR: Required file not found in example directory: ${_required}"
    exit 1
  fi
done

if [ -f "${EXAMPLE_DIR}/.env" ]; then
  cp "${EXAMPLE_DIR}/.env" .env
fi

unset _required_files _required
