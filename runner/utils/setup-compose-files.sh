# This file must be sourced, not executed directly.
# Requires: EXAMPLE_DIR (exported)
# Sets: COMPOSE_FILES

if [ -f "${EXAMPLE_DIR}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${EXAMPLE_DIR}/.env"
  set +a
fi

_ENVIRONMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILES=(-f "${_ENVIRONMENT_DIR}/docker-compose.yml")

if [ -f "${EXAMPLE_DIR}/docker-compose.override.yml" ]; then
  COMPOSE_FILES+=(-f "${EXAMPLE_DIR}/docker-compose.override.yml")
fi

KBN_INSTANCES=${KBN_INSTANCES:-1}
# shellcheck source=generate-kbn-instances.sh
source "$(dirname "${BASH_SOURCE[0]}")/generate-kbn-instances.sh"

unset _ENVIRONMENT_DIR
