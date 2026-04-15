#!/bin/bash
#
# Interactive arrow-key menu to pick an example.
# Prints the selected example name to stdout.
#

EXAMPLES_DIR="${1:-../examples}"

examples=()
descriptions=()
for dir in "$EXAMPLES_DIR"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  examples+=("$name")
  readme="$dir/README.md"
  if [ -f "$readme" ]; then
    desc=$(sed -n '3p' "$readme")
    descriptions+=("$name — $desc")
  else
    descriptions+=("$name")
  fi
done

if [ ${#examples[@]} -eq 0 ]; then
  echo "No examples found in $EXAMPLES_DIR" >&2
  exit 1
fi

cursor=0
count=${#descriptions[@]}

render_menu() {
  if [ "${first_render:-1}" -eq 0 ]; then
    printf '\033[%dA' "$count" >&2
  fi
  first_render=0
  for i in "${!descriptions[@]}"; do
    if [ "$i" -eq "$cursor" ]; then
      printf '\033[1m\033[7m > %s \033[0m\n' "${descriptions[$i]}" >&2
    else
      printf '   %s\n' "${descriptions[$i]}" >&2
    fi
  done
}

echo "Select an example to run (use arrow keys, press Enter to confirm):" >&2
echo "" >&2
tput civis >/dev/tty 2>/dev/null
trap 'tput cnorm >/dev/tty 2>/dev/null' EXIT
render_menu
while true; do
  IFS= read -rsn1 key </dev/tty
  case "$key" in
    $'\x1b')
      read -rsn2 seq </dev/tty
      case "$seq" in
        '[A') ((cursor > 0)) && ((cursor--)) ;;
        '[B') ((cursor < count - 1)) && ((cursor++)) ;;
      esac
      ;;
    '') break ;;
  esac
  render_menu
done
tput cnorm >/dev/tty 2>/dev/null
echo "" >&2

printf '%s' "${examples[$cursor]}"
