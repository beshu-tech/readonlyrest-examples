#!/bin/bash

# Runs a command in the background while showing an animated dot spinner.
# Usage: run-with-spinner.sh <message> <cmd> [args...]
# Exits with the command's exit code; prints its output only on failure.

MSG="${1:?Usage: run-with-spinner.sh <message> <cmd> [args...]}"
shift

printf '%s' "$MSG"

LOG=$(mktemp)
"$@" > "$LOG" 2>&1 &
CMD_PID=$!

DOT_FRAMES=("." ".." "...")
_i=0
while kill -0 "$CMD_PID" 2>/dev/null; do
  printf '\r%s%-3s' "$MSG" "${DOT_FRAMES[$_i]}"
  _i=$(( (_i + 1) % 3 ))
  sleep 0.5
done
printf '\n'

if ! wait "$CMD_PID"; then
  cat "$LOG"
  rm -f "$LOG"
  exit 1
fi
rm -f "$LOG"
