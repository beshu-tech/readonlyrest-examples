# This file must be sourced, not executed directly.
# Usage: source resolve-example-dir.sh [example-name]
# Requires: called from the runner/ directory (cd "$(dirname "$0")" first)
# Sets: EXAMPLE_DIR, COMPOSE_FILES (via setup-compose-files.sh)

_example_name="${1:-}"
if [ -z "$_example_name" ]; then
  if [ -f .current-example ]; then
    _example_name="$(cat .current-example)"
    echo "No example specified, using last run: $_example_name"
  else
    echo "Usage: $0 <example-name>"
    echo "Example: $0 basic"
    exit 1
  fi
fi

_example_arg="$_example_name"
if [[ "$_example_arg" != */* ]]; then
  _example_arg="../examples/$_example_arg"
fi

if [ ! -d "$_example_arg" ]; then
  echo "ERROR: Example '${_example_name}' not found."
  echo ""
  echo "Available examples:"
  for _dir in ../examples/*/; do
    [ -d "$_dir" ] && echo "  - $(basename "$_dir")"
  done
  # Suggest close matches (substring)
  _matches=()
  for _dir in ../examples/*/; do
    _name="$(basename "$_dir")"
    if [[ "$_name" == *"${_example_name}"* || "${_example_name}" == *"$_name"* ]]; then
      _matches+=("$_name")
    fi
  done
  if [ ${#_matches[@]} -gt 0 ]; then
    echo ""
    echo "Did you mean:"
    for _m in "${_matches[@]}"; do
      echo "  $0 $_m"
    done
  fi
  unset _dir _name _matches _m
  exit 1
fi

export EXAMPLE_DIR
EXAMPLE_DIR="$(cd "$_example_arg" && pwd)"

# shellcheck source=setup-compose-files.sh
source "$(dirname "${BASH_SOURCE[0]}")/setup-compose-files.sh"

unset _example_name _example_arg
