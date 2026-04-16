#!/bin/bash -e

REPO_URL="https://github.com/beshu-tech/readonlyrest-examples.git"
REPO_DIR="readonlyrest-examples"

# Handle --clean flag
if [ "${1:-}" = "--clean" ]; then
  if [ ! -d "$REPO_DIR" ]; then
    echo "Nothing to clean — $REPO_DIR directory not found."
    exit 0
  fi
  cd "$REPO_DIR"
  exec ./clean.sh
fi

if [ -d "$REPO_DIR" ]; then
  echo "Found existing $REPO_DIR directory, updating ..."
  git -C "$REPO_DIR" pull --quiet
else
  echo "Cloning $REPO_URL ..."
  git clone --quiet "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
exec ./run.sh "$@"
