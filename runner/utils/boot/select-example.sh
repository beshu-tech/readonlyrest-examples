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
    descriptions+=("$desc")
  else
    descriptions+=("")
  fi
done

if [ ${#examples[@]} -eq 0 ]; then
  echo "No examples found in $EXAMPLES_DIR" >&2
  exit 1
fi

cursor=0
count=${#examples[@]}
_total_lines=0
_term_cols=$(tput cols 2>/dev/null || echo 80)

# Reserve vertical space so the first render doesn't scroll the saved position away
_reserve=$((count + 4))
printf "%${_reserve}s" "" | tr ' ' '\n' >/dev/tty
tput cuu "$_reserve" >/dev/tty 2>/dev/null
printf '\r' >/dev/tty

render_menu() {
  if [ "$_total_lines" -gt 0 ]; then
    tput cuu "$_total_lines" >/dev/tty 2>/dev/null
    printf '\r' >/dev/tty
  fi
  printf '\033[J' >/dev/tty
  for i in "${!examples[@]}"; do
    if [ "$i" -eq "$cursor" ]; then
      printf '\033[1m\033[7m > %s \033[0m\n' "${examples[$i]}" >/dev/tty
    else
      printf '   %s\n' "${examples[$i]}" >/dev/tty
    fi
  done
  _total_lines=$count
  local desc="${descriptions[$cursor]}"
  if [ -n "$desc" ]; then
    local max_len=$((_term_cols - 4))
    if [ "${#desc}" -gt "$max_len" ]; then
      desc="${desc:0:$((max_len - 3))}..."
    fi
    printf '\n   \033[2m%s\033[0m\n' "$desc" >/dev/tty
    _total_lines=$((_total_lines + 2))
  fi
}

echo "Select an example to run (use arrow keys, press Enter to confirm):" >/dev/tty
echo "" >/dev/tty
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
echo "" >/dev/tty

printf '%s' "${examples[$cursor]}"
