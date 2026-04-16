#!/bin/bash -e

cd "$(dirname "$0")" || exit 1

docker compose rm --stop --force