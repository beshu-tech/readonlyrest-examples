#!/bin/bash -e

REPO_URL="https://github.com/beshu-tech/readonlyrest-examples.git"
REPO_DIR="readonlyrest-examples"

# Parse --branch <name> out of the argument list; pass the rest to run.sh
BRANCH=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# Handle --clean flag
if [ "${ARGS[0]:-}" = "--clean" ]; then
  if [ ! -d "$REPO_DIR" ]; then
    echo "Nothing to clean — $REPO_DIR directory not found."
    exit 0
  fi
  cd "$REPO_DIR"
  ./clean.sh
  cd ..
  rm -rf "$REPO_DIR"
  echo "Removed $REPO_DIR directory."
  exit 0
fi

if [ -d "$REPO_DIR" ]; then
  echo "Found existing $REPO_DIR directory, updating ..."
  if [ -n "$BRANCH" ]; then
    git -C "$REPO_DIR" fetch --quiet
    git -C "$REPO_DIR" checkout --quiet "$BRANCH"
  fi
  git -C "$REPO_DIR" pull --quiet
else
  echo "Cloning $REPO_URL ..."
  if [ -n "$BRANCH" ]; then
    git clone --quiet -b "$BRANCH" "$REPO_URL" "$REPO_DIR"
  else
    git clone --quiet "$REPO_URL" "$REPO_DIR"
  fi
fi

cd "$REPO_DIR"
exec ./run.sh "${ARGS[@]}"
