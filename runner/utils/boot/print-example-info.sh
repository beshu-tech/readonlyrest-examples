#!/bin/bash

readme_path="${1}/README.md"
if [ ! -f "$readme_path" ]; then
  exit 0
fi

example_title="$(awk '/^# /{sub(/^# /, ""); print; exit}' "$readme_path")"
example_desc="$(awk '/^# /{found=1; next} found && /^[[:space:]]*$/{next} found && /^#/{exit} found{print; exit}' "$readme_path")"

echo "  Example: ${example_title}"
[ -n "$example_desc" ] && echo "  ${example_desc}"
echo ""
