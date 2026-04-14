#!/bin/bash
# License detection and validation utilities.
# Meant to be sourced from run.sh, not executed directly.
# Assumes the working directory is the runner/ directory.
# Requires: EXAMPLE_DIR, ROR_ACTIVATION_KEY (env vars)

detect_license_edition() {
  local output rc
  if output="$(./utils/boot/extract_license_edition.sh "${ROR_ACTIVATION_KEY}" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi

  if [ $rc -ne 0 ]; then
    echo "ERROR: Failed to extract the ROR license edition (exit code: $rc)." >&2
    echo "$output" >&2
    exit $rc
  elif [ -z "$output" ]; then
    echo "ERROR: Could not determine the ROR license edition (the extract_license_edition helper returned no result)." >&2
    exit 2
  fi

  ROR_LICENSE_EDITION="$output"
  echo "Auto-detected ROR_LICENSE_EDITION=$ROR_LICENSE_EDITION"
}

edition_rank() {
  case "$1" in
    FREE) echo 1 ;;
    PRO)  echo 2 ;;
    ENT)  echo 3 ;;
    *) echo "ERROR: Unknown license edition: $1 (expected FREE, PRO, or ENT)" >&2; exit 1 ;;
  esac
}

check_min_license_edition() {
  local example_arg="$1"
  local min_edition current_rank required_rank
  min_edition=$(grep -E '^ROR_MIN_LICENSE_EDITION=' "${EXAMPLE_DIR}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]')
  if [ -z "$min_edition" ]; then
    echo "ERROR: ROR_MIN_LICENSE_EDITION is not set in ${EXAMPLE_DIR}/.env. Set it to FREE, PRO, or ENT." >&2
    exit 1
  fi

  current_rank=$(edition_rank "$ROR_LICENSE_EDITION")
  required_rank=$(edition_rank "$min_edition")

  if [ "$current_rank" -lt "$required_rank" ]; then
    echo "ERROR: This example requires at least the $min_edition license edition, but your license is $ROR_LICENSE_EDITION." >&2
    echo "" >&2
    echo "  To obtain a trial activation key, visit:" >&2
    echo "  https://docs.readonlyrest.com/kibana#after-purchasing" >&2
    echo "" >&2
    echo "  Once you have the key, set it before running the example:" >&2
    echo "  export ROR_ACTIVATION_KEY=<your-activation-key>" >&2
    echo "  ./run.sh $example_arg" >&2
    exit 1
  fi
}

detect_license_edition
check_min_license_edition "$1"
