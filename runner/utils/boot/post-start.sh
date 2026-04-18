#!/bin/bash

# Source this script after the stack is up.
# Requires: EXAMPLE_DIR, COMPOSE_FILES

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
