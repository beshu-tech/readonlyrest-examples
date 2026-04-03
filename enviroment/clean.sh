#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

docker compose --profile ENT --profile PRO --profile FREE rm --stop --force